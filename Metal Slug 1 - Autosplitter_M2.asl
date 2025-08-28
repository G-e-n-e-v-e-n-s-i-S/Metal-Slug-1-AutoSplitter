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



	//An array of bytes to find the boss's health variable
	/*vars.scannerTargetBossHealth = new SigScanTarget(26,
   	"FF FF FF FF 10 00 ?? ?? ?? ?? ?? 01 00 ?? 00 ?? " +
   	"FF FF FF FF FF FF FF FF FF FF ?? ?? ?? 00 00 00 " +
   	"FF FF FF 00 ?? 00 ?? ?? FF ?? FF FF FF FF ?? ?? " +
   	"40 06 FF FF ?? ?? ?? 01 00 FF ?? FF FF ?? 01 ?? "
	);*/
	vars.scannerTargetBossHealth = new SigScanTarget(32,
   	"?? ?? 2D 00 C6 50 FF FF FF FF 10 00 ?? ?? ?? ?? " +
		"?? 01 00 ?? 00 ?? FF FF FF FF FF FF FF FF FF FF " +
		"?? ?? ?? 00 00 00 FF FF FF 00 ?? 00 ?? ?? FF ??"
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

		//The foot of the character when he hits the ground at the start of mission 2
		//Starts at pixel ( 58 , 150 )
		vars.colorsRunStart = new byte[]		{
													112, 160, 168, 0,
													112, 160, 168, 0,
													 72, 104, 112, 0,
													 40,  48,  48, 0,
													112, 136, 144, 0,
													152, 184, 192, 0,
													 40,  48,  48, 0,
													 72, 104, 112, 0,
													 72, 104, 112, 0,
													 72, 104, 112, 0
												};

		vars.offsetRunStart = 0x2C968
;

		//The vent of the reactor in the background while approaching the fight against the 2st boss
		//Starts at pixel ( 269 , 84 )
		vars.colorsBossStart = new byte[]		{
													 0,  40,  72, 0,
													 0,  48,  96, 0,
													 0,  64, 144, 0,
													 0,  24,  40, 0,
													 0,  24,  40, 0,
													 0,  40,  72, 0,
													 0,  40,  72, 0,
													 0,  32,  56, 0,
													 0,  24,  40, 0,
													 0,  24,  40, 0
												};

		vars.offsetBossStart = 0x19334;

	}



	else if (game.ProcessName.Equals("fcadefbneo"))
	{

		//The foot of the character when he hits the ground at the start of mission 2
		//Starts at pixel ( 58 , 150 )
		vars.colorsRunStart = new byte[] {
													115, 165, 173, 0,
													115, 165, 173, 0,
													115, 165, 173, 0,
													115, 165, 173, 0,
													74, 107, 115, 0,
													74, 107, 115, 0,
													41, 49, 49, 0,
													41, 49, 49, 0,
													115, 140, 148, 0,
													115, 140, 148, 0,
													156, 189, 198, 0,
													156, 189, 198, 0,
													41, 49, 49, 0,
													41, 49, 49, 0,
													74, 107, 115, 0
												};

		vars.offsetRunStart = 0xB23D0;


		//The vent of the reactor in the background while approaching the fight against the 2st boss
		//Starts at pixel ( 269 , 84 )
		vars.colorsBossStart = new byte[] {
													0, 41, 74, 0,
													0, 41, 74, 0,
													0, 49, 99, 0,
													0, 49, 99, 0,
													0, 66, 148, 0,
													0, 66, 148, 0,
													0, 24, 41, 0,
													0, 24, 41, 0,
													0, 24, 41, 0,
													0, 24, 41, 0,
													0, 41, 74, 0,
													0, 41, 74, 0,
													0, 41, 74, 0,
													0, 41, 74, 0,
													0, 33, 57, 0
												};


		vars.offsetBossStart = 0x64468;

	}



	else //if(game.ProcessName.Equals("mslug1"))
	{

		//The foot of the character when he hits the ground at the start of mission 2		// #TODO: The RGB values must be adapted for Steam
		//Starts at pixel ( 58 , 150 )
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

		vars.offsetRunStart = 0x4B117;



		//The vent of the reactor in the background while approaching the fight against the 2st boss		// #TODO: The RGB values must be adapted for Steam
		//Starts at pixel ( 269 , 84 )
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

		vars.offsetBossStart = 0x2A463;

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
		vars.splitCounter = 10;

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
		vars.splitCounter = 10;

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

	//Check time since last split, don't split if we already split in the last 8 seconds
	var timeSinceLastSplit = Environment.TickCount - vars.prevSplitTime;

	if (vars.prevSplitTime != -1 && timeSinceLastSplit < 8000)
	{
		return false;
	}



	//If we dont know where the screen is, stop
	if (vars.pointerScreen == IntPtr.Zero)
	{
		return false;
	}


	//Knowing when we get to the last boss
	else if (vars.splitCounter == 10)
	{

		//When the pillar of the hangar becomes visible
		byte[] pixels = vars.ReadArray(game, vars.offsetBossStart);
		//DEBUG: print("[MS1 AutoSplitter] Scanning for boss start");

		if (vars.MatchArray(pixels, vars.colorsBossStart))
		{

			//Clear the pointer to the boss's health
			vars.pointerBossHealth = IntPtr.Zero;
			//DEBUG: print("[MS1 AutoSplitter] Boss started");



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
			vars.pointerBossHealth = vars.FindArray(game, vars.scannerTargetBossHealth);



			//If the scan was successful
			if (vars.pointerBossHealth != IntPtr.Zero)
			{

				//Notify
				print("[MS1 AutoSplitter] Found health at: 0x" + vars.pointerBossHealth.ToString("X"));

				//Create a new memory watcher
				vars.watcherBossHealth = new MemoryWatcher<short>(vars.pointerBossHealth);

				vars.watcherBossHealth.Update(game);

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
		vars.watcherBossHealth.Update(game);

		if (vars.watcherBossHealth.Current > 0)
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
		vars.watcherBossHealth.Update(game);



		//Count how many successive frames the boss's health stayed at 0
		if (vars.watcherBossHealth.Current == 0)
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
