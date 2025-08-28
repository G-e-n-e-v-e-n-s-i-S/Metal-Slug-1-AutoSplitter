state("mslug1")
{

}

state("WinKawaks")
{
	int pointerScreen : 0x0046B270;
}

state("fcadefbneo")
{
	int pointerScreen : 0x02D73FD0, 0x4, 0xF4;
	//int pointerScreen : 0x02D4D8D4, 0x4, 0x4, 0x14;
}





startup
{

	vars.FindArrayMulti = new Func<Process, SigScanTarget, int, IntPtr>((process, target, occurrence) =>
    {
        if (occurrence <= 0) occurrence = 1;
        int seen = 0;

        foreach (var page in process.MemoryPages())
        {
            var scanner = new SignatureScanner(process, page.BaseAddress, (int)page.RegionSize);
            var results = scanner.ScanAll(target);

            if (results != null)
            {
                foreach (var r in results)
                {
                    seen++;
                    if (seen == occurrence)
                        return r;
                }
            }
        }

        return IntPtr.Zero;
    });

	//A function that finds an array of bytes in memory
	Func<Process, SigScanTarget, IntPtr> FindArray = (process, target) =>
	{

		IntPtr pointer = IntPtr.Zero;

		foreach (var page in process.MemoryPages())
		{

			var scanner = new SignatureScanner(process, page.BaseAddress, (int)page.RegionSize);

			pointer = scanner.Scan(target);

			if (pointer != IntPtr.Zero) break;

		}

		return pointer;

	};

	vars.FindArray = FindArray;



	//A function that reads an array of 60 bytes in the screen memory
	Func<Process, int, byte[]> ReadArray = (process, offset) =>
	{

		byte[] bytes = new byte[60];

		bool succes = ExtensionMethods.ReadBytes(process, vars.pointerScreen + offset, 60, out bytes);

		if (!succes)
		{
			print("[MS1 AutoSplitter] Failed to read screen");
		}

		return bytes;

	};

	vars.ReadArray = ReadArray;



	//A function that matches two arrays of bytes
	Func<byte[], byte[], bool> MatchArray = (bytes, colors) =>
	{

		if (bytes == null)
		{
			return false;
		}

		for (int i = 0; i < bytes.Length && i < colors.Length; i++)
		{

			if (bytes[i] != colors[i])
			{
				return false;
			}
		}

		return true;

	};

	vars.MatchArray = MatchArray;



	//A function that prints an array of bytes
	Action<byte[]> PrintArray = (bytes) =>
	{

		if (bytes == null)
		{
			print("[MS1 AutoSplitter] Bytes are null");
		}

		else
		{
			var str = new System.Text.StringBuilder();

			for (int i = 0; i < bytes.Length; i++)
			{
				str.Append(bytes[i].ToString());

				str.Append(",");

				if (i % 4 == 3) str.Append("\n");

				else str.Append("\t");
			}

			print(str.ToString());
		}
	};

	vars.PrintArray = PrintArray;



	//Should we reset and restart the timer
	vars.restart = false;



	//The time at which the last reset happenend
	vars.prevRestartTime = Environment.TickCount;



	//An array of bytes to find the screen's pixel array memory region
	vars.scannerTargetScreen = new SigScanTarget(0, "10 08 00 00 ?? ?? 00 ?? ?? ?? ?? 00 00 00 04 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 20");



	//The pointer to the screen's pixel array memory region, once we found it with the scan
	vars.pointerScreen = IntPtr.Zero;



	//A watcher for this pointer
	vars.watcherScreen = new MemoryWatcher<short>(IntPtr.Zero);

	vars.watcherScreen.FailAction = MemoryWatcher.ReadFailAction.SetZeroOrNull;



	//The time at which the last scan for the screen region happenend
	vars.prevScanTimeScreen = -1;


	//Note that this level has 2 final bosses: when the first boss dies, another scan must be performed
	//An array of bytes to find the top tank health variable
	vars.scannerTargetBossHealth1 = new SigScanTarget(32,
		"00 ?? 2D 00 8C 89 2D 00 68 90 ?? ?? ?? ?? ?? ?? " +
		"?? ?? 00 ?? 00 ?? FF FF FF FF 2D 00 E4 90 00 00 " +
		"?? ?? ?? 00 00 00 FF FF FF ?? ?? 00 ?? 00 ?? 00 " +
		"?? FF FF FF FF FF FF FF FF FF FF ?? ?? ?? ?? ??"
	);


	//The pointer to the boss's health, once we found it with the scan
	vars.pointerBossHealth = IntPtr.Zero;



	//A watcher for this pointer
	vars.watcherBossHealth = new MemoryWatcher<short>(IntPtr.Zero);



	//The time at which the last scan happenend
	vars.prevScanTimeBossHealth = -1;



	//The time at which the last split happenend
	vars.prevSplitTime = -1;



	//The split/state we are currently on
	vars.splitCounter = 0;



	//The counter to make sure Morden's Health stays at zero
	vars.confirmKillCounter = 0;



	//A local tickCount to do stuff sometimes
	vars.localTickCount = 0;

}





init
{

	//Set refresh rate
	refreshRate = 60;


	/*
	 *
	 * The various color arrays we will be checking for throughout the game
	 * Colors must be formated as : Blue, Green, Red, Alpha
	 *
	 * On the Steam version, Alpha seems to always be 255
	 * On the Steam version, the offset is 0x40 + X * 0x4 + Y * 0x800
	 *
	 * On the WinKawaks version, Alpha seems to always be 0
	 * On the WinKawaks version, the offset is X * 0x4 + Y * 0x500
	 *
	 */
	if(game.ProcessName.Equals("WinKawaks"))
	{

		//The exclamation mark in the "Mission Start!" text of mission 4
		//Starts at pixel ( 167 , 114 )
		vars.colorsRunStart = new byte[]		{
													48,  0,   0,   0,
													168, 168, 168, 0,
													0,   0,   0,   0,
													168, 168, 168, 0,
													168, 168, 168, 0,
													168, 168, 168, 0,
													168, 168, 168, 0,
													168, 0,   0,   0,
													168, 0,   0,   0,
													48,  0,   0,   0
												};

		vars.offsetRunStart = 0x2201C;
;

		//Start of the fight against the 4th boss 		// Skipped for this level
		//Starts at pixel ( 41, 163 )
		vars.colorsBossStart = new byte[]		{
													  40,  72,  80, 0,
													  16,  48,  64, 0,
													   0,  16,  24, 0,
													   0,  16,  24, 0,
													   0,  16,  24, 0,
													   0,  16,  24, 0,
													  64, 104, 112, 0,
													  56, 120, 128, 0,
													  32,  80,  88, 0,
													  56, 120, 128, 0
												};

		vars.offsetBossStart = 0x306E4;

	}



	else if (game.ProcessName.Equals("fcadefbneo"))
	{

		//The exclamation mark in the "Mission Start!" text of mission 4
		//Starts at pixel ( 167 , 114 )
		vars.colorsRunStart = new byte[] {
													49, 0, 0, 0,
													49, 0, 0, 0,
													173, 173, 173, 0,
													173, 173, 173, 0,
													0, 0, 0, 0,
													0, 0, 0, 0,
													173, 173, 173, 0,
													173, 173, 173, 0,
													173, 173, 173, 0,
													173, 173, 173, 0,
													173, 173, 173, 0,
													173, 173, 173, 0,
													173, 173, 173, 0,
													173, 173, 173, 0,
													148, 0, 0, 0
												};

		vars.offsetRunStart = 0x87B38;


		//Start of the fight against the 4th Boss 	// Skipped for this level	// #TODO: The RGB values must be adapted for fcadefbneo
		//Starts at pixel ( 41, 163 )
		vars.colorsBossStart = new byte[]		{
													99,  115, 123, 0,
													99,  115, 123, 0,
													107, 140, 148, 0,
													107, 140, 148, 0,
													107, 140, 148, 0,
													107, 140, 148, 0,
													107, 140, 148, 0,
													107, 140, 148, 0,
													99,  115, 123, 0,
													99,  115, 123, 0,
													82,  99,  99,  0,
													82,  99,  99,  0,
													66,  74,  74,  0,
													66,  74,  74,  0,
													82,  99,  99,  0
												};

		vars.offsetBossStart = 0xC1A48;

	}



	else //if(game.ProcessName.Equals("mslug1"))
	{

		//The exclamation mark in the "Mission Start!" text of mission 4		// #TODO: The RGB values must be adapted for Steam
		//Starts at pixel ( 167 , 114 )
		vars.colorsRunStart = new byte[]		{
													66,  97,  123, 255,
													24,  56,  74,  255,
													49,  73,  90,  255,
													115, 178, 206, 255,
													49,  73,  90,  255,
													49,  73,  90,  255,
													41,  73,  99,  255,
													41,  48,  49,  255,
													74,  105, 115, 255,
													74,  105, 115, 255
												};

		vars.offsetRunStart = 0x392CB;



		//Start of the fight against the 4th boss		// Skipped for this level	// #TODO: The RGB values must be adapted for Steam
		//Starts at pixel ( 41, 163 )
		vars.colorsBossStart = new byte[]		{
													99,  113, 123, 255,
													107, 138, 148, 255,
													107, 138, 148, 255,
													107, 138, 148, 255,
													99,  113, 123, 255,
													82,  97,  99,  255,
													66,  73,  74,  255,
													82,  97,  99,  255,
													82,  97,  99,  255,
													66,  73,  74,  255
												};

		vars.offsetBossStart = 0x518D3;

	}
}





exit
{

	//The pointers and watchers are no longer valid
	vars.pointerScreen = IntPtr.Zero;

	vars.watcherScreen = new MemoryWatcher<short>(IntPtr.Zero);

	vars.watcherScreen.FailAction = MemoryWatcher.ReadFailAction.SetZeroOrNull;

	vars.pointerBossHealth = IntPtr.Zero;

	vars.watcherBossHealth = new MemoryWatcher<short>(IntPtr.Zero);

}





update
{
	//Increase local tickCount
	vars.localTickCount = vars.localTickCount + 1;



	//Try to find the screen
	//For Kawaks and FightCade, follow the pointer path
	if(game.ProcessName.Equals("WinKawaks") || game.ProcessName.Equals("fcadefbneo"))
	{
		vars.pointerScreen = new IntPtr(current.pointerScreen);
	}

	//For Steam, do a scan
	else
	{

		//If the screen region changed place in memory
		vars.watcherScreen.Update(game);

		if (vars.watcherScreen.Changed)
		{

			//Void the pointer
			vars.pointerScreen = IntPtr.Zero;

		}



		//If the screen pointer is void
		if (vars.pointerScreen == IntPtr.Zero)
		{

			//If the screen scan cooldown has elapsed
			var timeSinceLastScan = Environment.TickCount - vars.prevScanTimeScreen;

			if (timeSinceLastScan > 300)
			{

				//Notify
				print("[MS1 AutoSplitter] Scanning for screen");



				//Scan for the screen
				vars.pointerScreen = vars.FindArray(game, vars.scannerTargetScreen);



				//If the scan was successful
				if (vars.pointerScreen != IntPtr.Zero)
				{

					//Notify
					print("[MS1 AutoSplitter]  Found screen");



					//Create a new memory watcher
					vars.watcherScreen = new MemoryWatcher<short>(vars.pointerScreen);

					vars.watcherScreen.FailAction = MemoryWatcher.ReadFailAction.SetZeroOrNull;

				}



				//Write down scan time
				vars.prevScanTimeScreen = Environment.TickCount;

			}
		}
	}



	//If we know where the screen is
	if (vars.pointerScreen != IntPtr.Zero)
	{

/*
		//Debug print
		if (vars.localTickCount % 10 == 0)
		{
			print("[MS1 AutoSplitter] Debug " + vars.splitCounter.ToString());

			vars.PrintArray(vars.ReadArray(game, vars.offsetRunStart));
			int myOffset = 0x2C978;
			byte[] arr = vars.ReadArray(game, myOffset);
			print("Offset 0x" + myOffset.ToString("X") + ": " + string.Join(",", arr));
		}
*/


		//Check time since last reset, don't reset if we already reset in the last second
		var timeSinceLastReset = Environment.TickCount - vars.prevRestartTime;

		if (timeSinceLastReset< 3000)
		{
			vars.restart = false;
		}

		//Otherwise, check if we should start/restart the timer
		else
		{
			vars.restart = vars.MatchArray(vars.ReadArray(game, vars.offsetRunStart), vars.colorsRunStart);
		}
	}
}





reset
{

	if (vars.restart)
	{
		vars.splitCounter = 11;	// Skips directly to boss health scan, since the boss fight doesn't have a fixed frame that can be scanned to retrieve the start of the boss fight

		vars.confirmKillCounter = 0;

		vars.prevRestartTime = Environment.TickCount;

		vars.prevSplitTime = -1;

		vars.prevScanTimeScreen = -1;

		vars.prevScanTimeBossHealth = -1;

		vars.pointerBossHealth = IntPtr.Zero;

		vars.watcherBossHealth = new MemoryWatcher<short>(IntPtr.Zero);

		return true;
	}
}





start
{

	if (vars.restart)
	{
		vars.splitCounter = 11;	 //Skips directly to boss health scan, since the boss fight doesn't have a fixed frame that can be scanned to retrieve the start of the boss fight

		vars.confirmKillCounter = 0;

		vars.prevRestartTime = Environment.TickCount;

		vars.prevSplitTime = -1;

		vars.prevScanTimeScreen = -1;

		vars.prevScanTimeBossHealth = -1;

		vars.pointerBossHealth = IntPtr.Zero;

		vars.watcherBossHealth = new MemoryWatcher<short>(IntPtr.Zero);

		return true;
	}
}





split
{

/*
	//DEBUG PRINT SCREEN RGBA
	var data = vars.ReadArray(game, vars.offsetRunStart);
	print("new byte[] { " + string.Join(", ", data) + " };");//A function that finds an array of bytes in memory
*/

	//Check time since last split, don't split if we already split in the last 10 seconds
	var timeSinceLastSplit = Environment.TickCount - vars.prevSplitTime;
	var timeSinceLastRestart = Environment.TickCount - vars.prevRestartTime;

	if (timeSinceLastRestart < 30000) 	//Longer time to start scanning for the boss health (avoids too many scans)

	{
		return false;
	}



	//If we dont know where the screen is, stop
	if (vars.pointerScreen == IntPtr.Zero)
	{
		return false;
	}


	//Knowing when we get to the last boss (skipped for this level)
	else if (vars.splitCounter == 10)
	{
		timeSinceLastSplit = Environment.TickCount - vars.prevSplitTime;


		//Start of the boss fight (skipped for this level)
		byte[] pixels = vars.ReadArray(game, vars.offsetBossStart);

		if (vars.MatchArray(pixels, vars.colorsBossStart))
		{

			//Clear the pointer to the boss's health
			vars.pointerBossHealth = IntPtr.Zero;



			//Move to next phase, prevent splitting/scanning for a while (but don't actually split)
			vars.splitCounter++;

			vars.prevSplitTime = Environment.TickCount;

		}
	}



	//Finding the boss's health variable
	else if (vars.splitCounter == 11)
	{

		//Check time since last scan, don't scan if we already scanned in the last 8 seconds
		//This should end up triggering about 2 or 3 times, which should be more than enough to find his health before the end of the fight
		var timeSinceLastScan = Environment.TickCount - vars.prevScanTimeBossHealth;

		if (timeSinceLastScan > 3000)
		{
    		//Notify
			print("[MS1 AutoSplitter] Scanning for health");


			//Scan
			vars.pointerBossHealth1 = vars.FindArrayMulti(game, vars.scannerTargetBossHealth1, 1);
			vars.pointerBossHealth2 = vars.FindArrayMulti(game, vars.scannerTargetBossHealth1, 2);
			//vars.pointerBossHealth2 = new IntPtr((long)vars.pointerBossHealth1 + 0x400C0);

						//If the scan was successful
			if (vars.pointerBossHealth1 != IntPtr.Zero && vars.pointerBossHealth2 != IntPtr.Zero)
			{
				//Notify
				print("[MS1 AutoSplitter] Found health boss 1 at: 0x" + vars.pointerBossHealth1.ToString("X"));
				print("[MS1 AutoSplitter] Found health boss 2 at: 0x" + vars.pointerBossHealth2.ToString("X"));

				//Create a new memory watcher
				vars.watcherBossHealth1 = new MemoryWatcher<short>(vars.pointerBossHealth1);
				vars.watcherBossHealth2 = new MemoryWatcher<short>(vars.pointerBossHealth2);

				vars.watcherBossHealth1.Update(game);
				vars.watcherBossHealth2.Update(game);


				//Move to next phase
				vars.splitCounter++;

			}

			//Write down scan time
			vars.prevScanTimeBossHealth = Environment.TickCount;

		}
	}



	//Check that the boss's health has been reset above 0
	else if (vars.splitCounter == 12)
	{

		//Update watcher
		vars.watcherBossHealth1.Update(game);
		vars.watcherBossHealth2.Update(game);

		if (vars.watcherBossHealth1.Current > 0 && vars.watcherBossHealth1.Current > 0)
		{

			//Go to next phase
			vars.splitCounter++;

			vars.confirmKillCounter = 0;

		}
	}



	//Check that the boss's health has been reduced to 0
	else if (vars.splitCounter == 13)
	{

		//Update watcher
		vars.watcherBossHealth1.Update(game);
		vars.watcherBossHealth2.Update(game);
		//Debug: print("[DEBUG] HP1 = " + vars.watcherBossHealth1.Current);
		//Debug: print("[DEBUG] HP2 = " + vars.watcherBossHealth2.Current);


		//Count how many successive frames the boss's health stayed at 0
		if (vars.watcherBossHealth1.Current <= 0 && vars.watcherBossHealth2.Current <= 0)
		{
			vars.confirmKillCounter++;
		}

		else
		{
			vars.confirmKillCounter = 0;
		}



		//Split if his health has stayed at 0 for more than 4 ticks
		if (vars.confirmKillCounter > 4)
		{
			vars.prevSplitTime = Environment.TickCount;

			vars.splitCounter++;

			return true;
		}
	}
}
