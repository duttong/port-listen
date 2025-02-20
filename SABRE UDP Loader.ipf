#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3				// Use modern global access method and strict wave access
#pragma DefaultTab={3,20,4}		// Set default tab width in Igor Pro 9 and later

Menu "Macros"
	"Load UCATS Telemetry Data /1", /Q, Load_UCATS_CSV()
	"Start automatic loading every 30 seconds", StartLoadTask()
	"Stop automatic loading", StopLoadTask()
	"-"
	"ECDs"
	"Omegas"
	"Pressures"
	"Flows"
	"Temperatures"
	"Voltage", Volts()
	"Mole_Fractions"
	"-"
	"Plot everythng", ECDs(); Omegas(); Pressures(); Flows(); Temperatures(); Volts(); Mole_Fractions()
	"-"
	"Tile all graphs", TileWindows/O=1/C/P
	"Close all graphs", rmDisplayedGraphs()
End

Function StartLoadTask()
	Variable numTicks = 30 * 60		// Run every 30 seconds
	CtrlNamedBackground loader, period=numTicks, proc=BkGload
	CtrlNamedBackground loader, start
End

Function StopLoadTask()
	CtrlNamedBackground loader, stop
End

Function BkGload(s)
	STRUCT WMBackgroundStruct &s
	
	//Printf "Task %s called, ticks=%d\r", s.name, s.curRunTicks
	Load_UCATS_CSV()
	return 0
end

Function Load_UCATS_CSV()

	SVAR /Z UCATSfile = S_UCATSfile
	//SVAR /Z UCATS_MTSfile = S_UCATS_MTSfile

	string file, files, DataPacketFile, MTSFile
	
	PathInfo DataPath
	if (V_flag == 0)
		NewPath/M="Select folder with UCATS UDP data files." DataPath
	endif
	
	// If S_UCATSfile exists use the file name stored in it. Delete the string to select a
	// different file.
	if (!SVAR_Exists(UCATSfile))
				
		files = filelist("data-")
		print files
		
		// if more than one file, ask for user input
		if (ItemsInList(files) != 1) 
			Prompt DataPacketFile, "Which file do you want to load.", popup, files
			DoPrompt "Loading UCATS UDP data", DataPacketFile
			if (V_Flag)
				return -1								// User canceled
			endif
		else
			DataPacketFile = StringFromList(0, files)
		endif

	else
		DataPacketFile = UCATSfile
	endif
	
	// If S_UCATS_MTSfile exists use the file name stored in it. Delete the string to select a
	// different file.
//	if (!SVAR_Exists(UCATS_MTSfile))
//		
//		//files = filelist("UCATSMTS_")
//		files = filelist("data-")
//		
//		// if more than one file, ask for user input
//		if (ItemsInList(files) != 1) 
//			Prompt MTSFile, "Which file do you want to load.", popup, files
//			DoPrompt "Loading UCATS MTS UDP data", MTSFile
//			if (V_Flag)
//				return -1								// User canceled
//			endif
//		else
//			MTSFile = StringFromList(0, files)
//		endif
//	else
//		MTSFile = UCATS_MTSfile
//	endif
	
	
	LoadUCBData(DataPacketFile)
	//LoadWave/Q/O/A/J/D/W/K=0/R={English,2,2,2,2,"Year-Month-DayOfMonth",40}/P=DataPath DataPacketFile
	//wave Xwave
	//Duplicate /o Xwave, datetimewv
	
	//LoadWave/Q/O/A/J/D/W/K=0/R={English,2,2,2,2,"Year-Month-DayOfMonth",40}/P=DataPath MTSFile
	//Duplicate /o Xwave, MTSxwave
	
	
	string /g S_UCATSfile = DataPacketFile
	//string /g S_UCATS_MTSfile = MTSFile

end

function /S filelist(prefix)
	string prefix
	
	string file, files2 = "", files = IndexedFile(DataPath, -1, ".csv")
	variable i
	
	if (ItemsInList(files) == 0)
		abort "No .csv files found"
	endif
	
	for(i=0; i<ItemsInList(files); i+=1)
		file = StringFromList(i, files)
		if (strsearch(file, prefix, 0) > -1)
			files2 += file + ";"
		endif
	endfor
	return files2
end

Function LoadUCBData(filePath)
    String filePath  //= "Macintosh HD:Users:gdutton:programming:SABRE telemetry:data-7075.csv"
    
    // Load the CSV file as waves
    LoadWave/A/J/O/D/W/K=0/Q/P=DataPath filePath
    
    // Assume the first column is source (text), and the second column is datetime (text)
    //Wave/T source = $"source"
    Wave/T datetimeStr = $"datetimeW"
    
    // Convert datetime strings to Igor datetime format
    Make/D/O/N=(DimSize(datetimeStr, 0)) datetimewv
    SetScale d 0,0,"dat", datetimewv
    Variable i, year, month, day, hour, minute, second
    
    for (i = 0; i < DimSize(datetimeStr, 0); i += 1)
        sscanf datetimeStr[i], "%4d%2d%2dT%2d%2d%2d", year, month, day, hour, minute, second
        datetimewv[i] = date2secs(year, month, day) + hour*60*60 + minute*60 + second
    endfor
    
    Print "Data loaded and datetime converted successfully."
End


Window ECD_temps() : Graph
	PauseUpdate; Silent 1		// building window...
	Display /W=(32,86,739,518) CH2_ECD vs datetimewv
	AppendToGraph CH1_ECD vs datetimewv
	AppendToGraph CH3_ECD vs datetimewv
	ModifyGraph rgb(CH2_ECD)=(19675,39321,1),rgb(CH3_ECD)=(26411,1,52428)
	ModifyGraph gaps=0
	ModifyGraph grid=1
	ModifyGraph mirror=2
	ModifyGraph dateInfo(bottom)={0,0,0}
	Label left "ECD Temp (C)"
	Label bottom "Day"
	SetAxis/A/N=1 left
	Legend/C/N=text0/J "\\s(CH1_ECD) CH1_ECD\n\\s(CH2_ECD) CH2_ECD\r\\s(CH3_ECD) CH3_ECD"
EndMacro

Window Column_temps() : Graph
	PauseUpdate; Silent 1		// building window...
	Display /W=(74,129,781,561) CH1_Col vs datetimewv
	AppendToGraph CH2_Col vs datetimewv
	AppendToGraph CH3_Col vs datetimewv
	AppendToGraph/R CH3_Post vs datetimewv
	ModifyGraph lSize(CH3_Post)=2
	ModifyGraph rgb(CH2_Col)=(19675,39321,1),rgb(CH3_Col)=(26411,1,52428),rgb(CH3_Post)=(52428,34958,1)
	ModifyGraph gaps=0
	ModifyGraph grid(bottom)=1
	ModifyGraph mirror(bottom)=2
	ModifyGraph dateInfo(bottom)={0,0,0}
	Label left "Col Temp (C)"
	Label bottom "Day"
	Label right "Post Col Temp (C)"
	SetAxis left 30,90
	SetAxis right 100,200
	Legend/C/N=text0/J/X=3.03/Y=15.19 "\\s(CH1_Col) CH1_Col\n\\s(CH2_Col) CH2_Col\r\\s(CH3_Col) CH3_Col\r\\s(CH3_Post) CH3_Post"
EndMacro

Macro Omegas()
    doWindow /k ECD_temps
    doWindow /k Column_temps
	ECD_temps()
	Column_temps()
end

Macro ECDs()
	doWindow /k ch1_resp
	doWindow /k ch2_resp
	doWindow /k ch3_resp
	doWindow /k ECD_Pressure
	ECD_Pressure()
	ch1_resp()
	ch2_resp()
	ch3_resp()
End

Window ch1_resp() : Graph
	PauseUpdate; Silent 1		// building window...
	Display /W=(35,66,675,310) ecdA_CH1 vs datetimewv
	ModifyGraph gaps=0
	ModifyGraph dateInfo(bottom)={0,0,0}
	ModifyGraph grid=1,mirror=2
	Label left "Channel 1 (Hz)"
	Label bottom "Day"
EndMacro

Window ch2_resp() : Graph
	PauseUpdate; Silent 1		// building window...
	Display /W=(68,119,704,362) ecdA_CH2 vs datetimewv
	ModifyGraph gaps=0
	ModifyGraph dateInfo(bottom)={0,0,0}
	ModifyGraph grid=1,mirror=2
	Label left "Channel 2 (Hz)"
	Label bottom "Day"
EndMacro

Window ch3_resp() : Graph
	PauseUpdate; Silent 1		// building window...
	Display /W=(103,161,739,402) ecdA_CH3 vs datetimewv
	ModifyGraph gaps=0
	ModifyGraph dateInfo(bottom)={0,0,0}
	ModifyGraph grid=1,mirror=2
	Label left "Channel 3 (Hz)"
	Label bottom "Day"
EndMacro

Window Chan1_flows() : Graph
	PauseUpdate; Silent 1		// building window...
	Display /W=(829,70,1224,278) flow_M1,flow_BF1 vs datetimewv
	ModifyGraph rgb(flow_M1)=(1,16019,65535)
	ModifyGraph gaps=0
	ModifyGraph grid=1
	ModifyGraph mirror=2
	ModifyGraph dateInfo(bottom)={0,0,0}
	Label left "Chan1 Flows (sccm)"
	Label bottom "Day"
	Legend/C/N=text0/J "\\JC\\f01Channel 1\\f00\r\\JL\\s(flow_M1) Main\r\\s(flow_BF1) Backflush"
EndMacro

Window Chan2_flows() : Graph
	PauseUpdate; Silent 1		// building window...
	Display /W=(860,95,1255,303) flow_M2,flow_BF2 vs datetimewv
	ModifyGraph rgb(flow_M2)=(1,16019,65535)
	ModifyGraph gaps=0
	ModifyGraph grid=1
	ModifyGraph mirror=2
	ModifyGraph dateInfo(bottom)={0,0,0}
	Label left "Chan2 Flows (sccm)"
	Label bottom "Day"
	Legend/C/N=text0/J "\\JC\\f01Channel 2\\f00\r\\JL\\s(flow_M2) Main\r\\s(flow_BF2) Backflush"
EndMacro

Window Chan3_flows() : Graph
	PauseUpdate; Silent 1		// building window...
	Display /W=(893,123,1288,331) flow_M3,flow_BF3 vs datetimewv
	ModifyGraph rgb(flow_M3)=(1,16019,65535)
	ModifyGraph gaps=0
	ModifyGraph grid=1
	ModifyGraph mirror=2
	ModifyGraph dateInfo(bottom)={0,0,0}
	Label left "Chan3 Flows (sccm)"
	Label bottom "Day"
	Legend/C/N=text0/J "\\JC\\f01Channel 3\\f00\r\\JL\\s(flow_M3) Main\r\\s(flow_BF3) Backflush"
EndMacro

Macro Flows()
	doWindow /K Chan1_flows
	doWindow /K Chan2_flows
	doWindow /K Chan3_flows
	doWindow /K Sample_Loop_Flow
	Chan1_flows()
	Chan2_flows()
	Chan3_flows()
	Sample_Loop_Flow()
End

Window High_Pressures() : Graph
	PauseUpdate; Silent 1		// building window...
	Display /W=(35,66,430,274) presH_123 vs datetimewv
	ModifyGraph gaps=0
	ModifyGraph grid=1
	ModifyGraph mirror=2
	ModifyGraph dateInfo(bottom)={0,0,0}
	Label left "Pressure (psi)"
	Label bottom "Day"
	Legend/C/N=text0/J "\\s(presH_123) presH_123"
EndMacro

Window Low_Pressures() : Graph
	PauseUpdate; Silent 1		// building window...
	Display /W=(72,105,467,313) presL_cal,presL_dope,presL_N2 vs datetimewv
	ModifyGraph rgb(presL_dope)=(19675,39321,1),rgb(presL_N2)=(1,16019,65535)
	ModifyGraph gaps=0
	ModifyGraph grid=1
	ModifyGraph mirror=2
	ModifyGraph dateInfo(bottom)={0,0,0}
	Label left "Low Pressures (psi)"
	Label bottom "Day"
	Legend/C/N=text0/J "\\s(presL_cal) presL_cal\r\\s(presL_dope) presL_dope\r\\s(presL_N2) presL_N2"
EndMacro

Macro Pressures()
	doWindow /K High_Pressures
	doWindow /K Low_Pressures
	doWindow /K BackPress
	doWindow /K Press_pump_etc
	High_Pressures()
	Low_Pressures()
	BackPress()
	Press_pump_etc()
End

function rmDisplayedGraphs()
	string grNm
	variable inc=0
	do 
		inc += 1
		grNm=WinName (0,5)
		if (strlen (grNm) <= 0)
			break
		endif
		if (mod(inc,5)==0) 
			printf "%s\r", grNm
		else
			printf "%s,", grNm
		endif
		doWindow /K $grNm
	while (1)
	printf "\r"
end

Window ECD_Pressure() : Graph
	PauseUpdate; Silent 1		// building window...
	Display /W=(102,434,740,720) pres_ECD1,pres_ECD2,pres_ECD3 vs DateTimeWv
	ModifyGraph rgb(pres_ECD2)=(19675,39321,1),rgb(pres_ECD3)=(26411,1,52428)
	ModifyGraph gaps=0
	ModifyGraph grid=1
	ModifyGraph mirror=2
	ModifyGraph dateInfo(bottom)={0,0,0}
	Label left "ECD Pressure (mbar)"
	Label bottom "Day"
	Legend/C/N=text0/J "\\s(pres_ECD1) pres_ECD1\r\\s(pres_ECD2) pres_ECD2\r\\s(pres_ECD3) pres_ECD3"
EndMacro

Window BackPress() : Graph
	PauseUpdate; Silent 1		// building window...
	Display /W=(463,454,858,662) pres_BP1,pres_BP2,pres_BP3 vs datetimewv
	ModifyGraph rgb(pres_BP2)=(19675,39321,1),rgb(pres_BP3)=(26411,1,52428)
	ModifyGraph gaps=0
	ModifyGraph grid=1
	ModifyGraph mirror=2
	ModifyGraph dateInfo(bottom)={0,0,0}
	Label left "Back Pressure (psi)"
	Label bottom "Day"
	Legend/C/N=text0/J "\\s(pres_BP1) pres_BP1\r\\s(pres_BP2) pres_BP2\r\\s(pres_BP3) pres_BP3"
EndMacro

Window Press_pump_etc() : Graph
	PauseUpdate; Silent 1		// building window...
	Display /W=(468,213,863,421) pres_extern,pres_PUMP,pres_SL vs datetimewv
	ModifyGraph rgb(pres_PUMP)=(19675,39321,1),rgb(pres_SL)=(26411,1,52428)
	ModifyGraph gaps=0
	ModifyGraph grid=1
	ModifyGraph mirror=2
	ModifyGraph dateInfo(bottom)={0,0,0}
	Label left "Pressure (mbar)"
	Label bottom "Day"
	Legend/C/N=text0/J "\\s(pres_extern) pres_extern\r\\s(pres_PUMP) pres_PUMP\r\\s(pres_SL) pres_SL"
EndMacro

Window Temps() : Graph
	PauseUpdate; Silent 1		// building window...
	Display /W=(706,66,1101,274) temp_amb,temp_gasB_C,temp_gasB_N,temp_pump vs datetimewv
	ModifyGraph rgb(temp_gasB_C)=(1,16019,65535),rgb(temp_gasB_N)=(19675,39321,1),rgb(temp_pump)=(44253,29492,58982)
	ModifyGraph gaps=0
	ModifyGraph grid=1
	ModifyGraph mirror=2
	ModifyGraph dateInfo(bottom)={0,0,0}
	Label left "Temperature (C)"
	Label bottom "Day"
	Legend/C/N=text0/J "\\s(temp_amb) temp_amb\r\\s(temp_gasB_C) temp_gasB_C\r\\s(temp_gasB_N) temp_gasB_N\r\\s(temp_pump) temp_pump"
EndMacro

Window Sample_Loop_Temps() : Graph
	PauseUpdate; Silent 1		// building window...
	Display /W=(753,111,1148,319) temp_SL1,temp_SL2,temp_SL3 vs datetimewv
	ModifyGraph rgb(temp_SL2)=(19675,39321,1),rgb(temp_SL3)=(26411,1,52428)
	ModifyGraph gaps=0
	ModifyGraph grid=1
	ModifyGraph mirror=2
	ModifyGraph dateInfo(bottom)={0,0,0}
	Label left "Temperatures (C)"
	Label bottom "Day"
	Legend/C/N=text0/J "\\JC\\f01Sample Loops\\f00\r\\JL\\s(temp_SL1) temp_SL1\r\\s(temp_SL2) temp_SL2\r\\s(temp_SL3) temp_SL3"
EndMacro

Macro Temperatures()
	doWindow /k Temps 
	doWindow /k Sample_Loop_Temps
	Temps()
	Sample_Loop_Temps()
End

Window Volts() : Graph
	PauseUpdate; Silent 1		// building window...
	Display /W=(937,74,1332,282) volt_5,volt_15,volt_28 vs datetimewv
	ModifyGraph rgb(volt_15)=(19675,39321,1),rgb(volt_28)=(26411,1,52428)
	ModifyGraph gaps=0
	ModifyGraph grid=1
	ModifyGraph mirror=2
	ModifyGraph dateInfo(bottom)={0,0,0}
	Label left "Voltage (V)"
	Label bottom "Day"
	Legend/C/N=text0/J "\\s(volt_5) volt_5\r\\s(volt_15) volt_15\r\\s(volt_28) volt_28"
EndMacro

Window Sample_Loop_Flow() : Graph
	PauseUpdate; Silent 1		// building window...
	Display /W=(932,158,1327,366) flow_SL vs datetimewv
	ModifyGraph gaps=0
	ModifyGraph grid=1
	ModifyGraph mirror=2
	ModifyGraph dateInfo(bottom)={0,0,0}
	Label left "Sample Loop Flow (sccm)"
	Label bottom "Day"
EndMacro

Window Mole_Fractions() : Graph
	PauseUpdate; Silent 1		// building window...
	Display /W=(35,66,779,491) F11 vs datetimewv
	AppendToGraph N2O vs datetimewv
	AppendToGraph F12 vs datetimewv
	AppendToGraph/R CH4 vs datetimewv
	AppendToGraph/R=newaxis SF6 vs datetimewv
	AppendToGraph/R SF6 vs datetimewv
	ModifyGraph lSize=3
	ModifyGraph rgb(N2O)=(0,0,65535),rgb(F12)=(3,52428,1),rgb(CH4)=(0,0,0),rgb(SF6)=(44253,29492,58982)
	ModifyGraph lblPos(right)=55
	ModifyGraph dateInfo(bottom)={0,0,0}
	Label left "CFC11,  CFC12,  N2O"
	ModifyGraph lblMargin(left)=15
	Label bottom "Day"
	Label right "CH4"
	Label newaxis "SF6"
	ModifyGraph lblPos(newaxis)=50
	SetAxis left 100,*
	SetAxis newaxis 10,*
	SetAxis right 1600,*
	ModifyGraph standoff=0
	ModifyGraph mirror(bottom)=1
	Legend/C/N=text0/J/X=4.55/Y=9.22 "\\s(F11) CFC11\r\\s(N2O) N2O\r\\s(F12) CFC12\r\\s(CH4) CH4\r\\s(SF6) SF6"
EndMacro

Function ClearAllWaves()
    String waveLst, wvname
    Variable i, numWaves

    // Get a space-separated list of all waves in the current data folder
    waveLst = WaveList("*", ";", "")  
    numWaves = ItemsInList(waveLst, ";")  

    for (i = 0; i < numWaves; i++)
        wvname = StringFromList(i, waveLst, ";")  
        if (WaveExists($wvname))         
            wave w = $wvname
            Redimension/N=(0) w  // Set wave length to zero
        endif
    endfor
End