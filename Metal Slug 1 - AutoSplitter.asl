


state("mslug1")
{

}

state("WinKawaks")
{
	int pointerScreen : 0x0046B270;
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



	//A function that reads an array of 40 bytes in the screen memory
	Func<Process, int, byte[]> ReadArray = (process, offset) =>
	{

		byte[] bytes = new byte[40];

		bool succes = ExtensionMethods.ReadBytes(process, vars.pointerScreen + offset, 40, out bytes);

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

		for (int i = 0; i < bytes.Length; i++)
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
	vars.scannerTargetBossHealth = new SigScanTarget(10, "FF FF FF FF FF FF FF FF FF FF ?? ?? 00 ?? 00 00 FF FF FF 00 ?? ?? ?? ?? ?? ?? ?? ?? FF FF ?? ?? ?? ?? FF FF 02 ?? ?? ?? ?? ?? 80 80");



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
													64,		96,		120,	0,
													24,		56,		72,		0,
													48,		72,		88,		0,
													112,	176,	200,	0,
													48,		72,		88,		0,
													48,		72,		88,		0,
													40,		72,		96,		0,
													40,		48,		48,		0,
													72,		104,	112,	0,
													72,		104,	112,	0
												};
		
		vars.offsetRunStart = 0x36178;
		
		
		
		//The exclamation mark in the Mission Complete !" text
		//Starts at pixel ( 247 , 114 )
		vars.colorsExclamationMark = new byte[] {
													0,		0,		0,		0,
													248,	248,	248,	0,
													0,		0,		120,	0,
													48,		208,	248,	0,
													24,		144,	248,	0,
													48,		208,	248,	0,
													24,		144,	248,	0,
													48,		208,	248,	0,
													248,	248,	248,	0,
													0,		0,		0,		0
												};

		vars.offsetExclamationMark = 0x2215C;
		
		

		//The grey of the UI
		//Starts at pixel ( 80 , 8 )
		vars.colorsUI = new byte[]				{
													184,	168,	160,	0,
													184,	168,	160,	0,
													184,	168,	160,	0,
													184,	168,	160,	0,
													184,	168,	160,	0,
													184,	168,	160,	0,
													184,	168,	160,	0,
													184,	168,	160,	0,
													184,	168,	160,	0,
													184,	168,	160,	0
												};

		vars.offsetUI = 0x2740;
		
		
		
		//The pillar of the hangar in the background of the fight against Morden
		//Starts at pixel ( 283 , 157 )
		vars.colorsBossStart = new byte[]		{
													96,		112,	120,	0,
													104,	136,	144,	0,
													104,	136,	144,	0,
													104,	136,	144,	0,
													96,		112,	120,	0,
													80,		96,		96,		0,
													64,		72,		72,		0,
													80,		96,		96,		0,
													80,		96,		96,		0,
													64,		72,		72,		0
												};

		vars.offsetBossStart = 0x2EE2C;

	}



	else //if(game.ProcessName.Equals("mslug1"))
	{
		
		//The foot of the character when he hits the ground at the start of mission 1
		//Starts at pixel ( 62 , 182 )
		vars.colorsRunStart = new byte[]		{
													66,		97,		123,	255,
													24,		56,		74,		255,
													49,		73,		90,		255,
													115,	178,	206,	255,
													49,		73,		90,		255,
													49,		73,		90,		255,
													41,		73,		99,		255,
													41,		48,		49,		255,
													74,		105,	115,	255,
													74,		105,	115,	255
												};
		
		vars.offsetRunStart = 0x5B127;
	
		

		//The exclamation mark in the Mission Complete !" text
		//Starts at pixel ( 247 , 114 )
		vars.colorsExclamationMark = new byte[] {
													0,		0,		0,		255,
													255,	251,	255,	255,
													0,		0,		123,	255,
													49,		211,	255,	255,
													24,		146,	255,	255,
													49,		211,	255,	255,
													24,		146,	255,	255,
													49,		211,	255,	255,
													255,	251,	255,	255,
													0,		0,		0,		255
												};

		vars.offsetExclamationMark = 0x3940B;

		

		//The grey of the UI
		//Starts at pixel ( 80 , 8 )
		vars.colorsUI = new byte[]				{
													189,	170,	165,	255,
													189,	170,	165,	255,
													189,	170,	165,	255,
													189,	170,	165,	255,
													189,	170,	165,	255,
													189,	170,	165,	255,
													189,	170,	165,	255,
													189,	170,	165,	255,
													189,	170,	165,	255,
													189,	170,	165,	255
												};

		vars.offsetUI = 0x416F;
		
		
		
		//The pillar of the hangar in the background of the fight against Morden
		//Starts at pixel ( 283 , 157 )
		vars.colorsBossStart = new byte[]		{
													99,		113,	123,	255,
													107,	138,	148,	255,
													107,	138,	148,	255,
													107,	138,	148,	255,
													99,		113,	123,	255,
													82,		97,		99,		255,
													66,		73,		74,		255,
													82,		97,		99,		255,
													82,		97,		99,		255,
													66,		73,		74,		255
												};

		vars.offsetBossStart = 0x4EC9B;
		
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
	//For Kawaks, follow the pointer path
	if(game.ProcessName.Equals("WinKawaks"))
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
			
			//Notify
			print("[MS1 AutoSplitter] Screen region changed");



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
		
		//Debug print an array
		//print("Rugname");
		
		//vars.PrintArray(vars.ReadArray(game, vars.offsetExclamationMark));

		
	
		//Check if we should start/restart the timer
		vars.restart = vars.MatchArray(vars.ReadArray(game, vars.offsetExclamationMark), vars.colorsExclamationMark);
		
	}
}





reset
{
	
	if (vars.restart)
	{
		vars.splitCounter = 0;
		
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
		return true;
	}
}





split
{
	
	//Check time since last split, don't split if we already split in the last 10 seconds
	var timeSinceLastSplit = Environment.TickCount - vars.prevSplitTime;
	
	if (vars.prevSplitTime != -1 && timeSinceLastSplit < 10000)
	{
		return false;
	}
	
	
	
	//If we dont know where the screen is, stop
	if (vars.pointerScreen == IntPtr.Zero)
	{
		return false;
	}



	//Debug Print
	if (vars.localTickCount % 10 == 0)
	{
		byte[] bytes = vars.ReadArray(game, vars.offsetExclamationMark);

		var str = new System.Text.StringBuilder();

		for (int i = 0; i<bytes.Length; i++)
		{
			str.Append(bytes[i].ToString());

			str.Append(" ");
		}

		print(vars.splitCounter.ToString() + " - " + str.ToString());
	}



	//Missions 1, 2, 3, 4 and 5
	if (vars.splitCounter < 10)
	{
		
		if (vars.splitCounter % 2 == 0)
		{
			
			//Check for the exclamation mark from the "Mission Complete !" text
			byte[] pixels = vars.ReadArray(game, vars.offsetExclamationMark);
			
			if (vars.MatchArray(pixels, vars.colorsExclamationMark))
			{
				vars.splitCounter++;
			}
		}

		else
		{

			//Split when the UI disappears after we've seen the exclamation mark
			byte[] pixels = vars.ReadArray(game, vars.offsetUI);
			
			if (!vars.MatchArray(pixels, vars.colorsUI))
			{
				vars.splitCounter++;
			
				vars.prevSplitTime = Environment.TickCount;
			
				return true;
			}
		}
	}



	//Knowing when we get to the last boss
	else if (vars.splitCounter == 10)
	{
		
		//When the pillar of the hangar becomes visible
		byte[] pixels = vars.ReadArray(game, vars.offsetBossStart);
	
		if (vars.MatchArray(pixels, vars.colorsBossStart))
		{
			
			//Notify
			print("[MS1 AutoSplitter] Last fight starting");



			//Clear the pointer to the boss's health
			vars.pointerBossHealth = IntPtr.Zero;
			
			
			
			//Move to next phase, prevent splitting/scanning for 10 seconds (but don't actually split)
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
		
		if (timeSinceLastScan > 8000)
		{
			
			//Notify
			print("[MS1 AutoSplitter] Scanning for health");



			//Scan
			vars.pointerBossHealth = vars.FindArray(game, vars.scannerTargetBossHealth);
			
			
		
			//If the scan was successful
			if (vars.pointerBossHealth != IntPtr.Zero)
			{
				
				//Notify
				print("[MS1 AutoSplitter] Found health");



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
		
		vars.watcherBossHealth.Update(game);
		
		if (vars.watcherBossHealth.Current > 0)
		{
			
			//Notify
			print("[MS1 AutoSplitter] Monitoring health");



			//Go to next phase
			vars.splitCounter++;

		}
	}



	//Check that the boss's health has been reduced to 0
	else if (vars.splitCounter == 13)
	{

		//Update watcher
		vars.watcherBossHealth.Update(game);
		
		
		
		//Split when the boss's health reaches 0
		if (vars.watcherBossHealth.Current == 0)
		{
			print("[MS1 AutoSplitter] Run end");

			vars.splitCounter++;

			vars.prevSplitTime = Environment.TickCount;
			
			return true;
		}
	}
}
