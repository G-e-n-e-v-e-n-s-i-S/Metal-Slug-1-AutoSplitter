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
	vars.scannerTargetBossHealth = new SigScanTarget(19,
   	"?? ?? ?? ?? ?? 00 ?? 00 ?? FF FF FF FF 07 00 12 " +
   	"47 FF FF ?? ?? 00 06 00 00 FF FF FF ?? 00 ?? 98 " +
   	"08 ?? ?? 00 00 00 00 ?? 00 ?? 00 26 02 07 00 ??"
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

		//The foot of the character when he hits the ground at the start of mission 1
		//Starts at pixel ( 62 , 182 )
		vars.colorsRunStart = new byte[]		{
													64,  96,  120, 0,
													24,  56,  72,  0,
													48,  72,  88,  0,
													112, 176, 200, 0,
													48,  72,  88,  0,
													48,  72,  88,  0,
													40,  72,  96,  0,
													40,  48,  48,  0,
													72,  104, 112, 0,
													72,  104, 112, 0
												};

		vars.offsetRunStart = 0x36178;

		//The base of the cannon of the boss
		//Starts at pixel ( 228 , 202 )
		vars.colorsBossStart = new byte[]		{
													 96, 128, 136, 0,
													 96, 128, 136, 0,
													 48,  80,  88, 0,
													 48,  80,  88, 0,
													 96, 128, 136, 0,
													 16,  40,  40, 0,
													 16,  64,  80, 0,
													  8,  40,  56, 0,
													  8,  40,  56, 0,
													  8,  40,  56, 0
												};

		vars.offsetBossStart = 0x3C310;

	}



	else if (game.ProcessName.Equals("fcadefbneo"))
	{

		//The foot of the character when he hits the ground at the start of mission 1
		//Starts at pixel ( 62 , 182 )
		vars.colorsRunStart = new byte[]		{
													66,  99,  123, 0,
													66,  99,  123, 0,
													24,  57,  74,  0,
													24,  57,  74,  0,
													49,  74,  90,  0,
													49,  74,  90,  0,
													115, 181, 206, 0,
													115, 181, 206, 0,
													49,  74,  90,  0,
													49,  74,  90,  0,
													49,  74,  90,  0,
													49,  74,  90,  0,
													41,  74,  99,  0,
													41,  74,  99,  0,
													41,  49,  49,  0
												};

		vars.offsetRunStart = 0xD83F0;


		//The base of the cannon of the boss
		//Starts at pixel ( 228 , 202 )
		vars.colorsBossStart = new byte[] {
													99, 132, 140, 0,
													99, 132, 140, 0,
													99, 132, 140, 0,
													99, 132, 140, 0,
													49, 82, 90, 0,
													49, 82, 90, 0,
													49, 82, 90, 0,
													49, 82, 90, 0,
													99, 132, 140, 0,
													99, 132, 140, 0,
													16, 41, 41, 0,
													16, 41, 41, 0,
													16, 66, 82, 0,
													16, 66, 82, 0,
													8, 41, 57, 0
												};

		vars.offsetBossStart = 0xF0520;

	}



	else //if(game.ProcessName.Equals("mslug1"))
	{

		//The foot of the character when he hits the ground at the start of mission 1
		//Starts at pixel ( 62 , 182 )
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

		vars.offsetRunStart = 0x5B127;



		//The base of the cannon of the boss // #TODO: The RGB values must be adapted for Steam
		//Starts at pixel ( 228 , 202 )
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

		vars.offsetBossStart = 0x653BF;

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

	//Check time since last split, don't split if we already split in the last 1 second
	var timeSinceLastSplit = Environment.TickCount - vars.prevSplitTime;

	if (vars.prevSplitTime != -1 && timeSinceLastSplit < 1000)
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
		//When the base of the cannon of the boss becomes visible
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

		if (timeSinceLastScan > 2500)
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
				print("[DEBUG] HP = " + vars.watcherBossHealth.Current);



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
