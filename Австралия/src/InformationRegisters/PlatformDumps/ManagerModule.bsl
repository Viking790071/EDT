#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Private

Function GetDumpsToDelete() Export
	Query = New Query;
	Query.Text = 
	"SELECT
	|	PlatformDumps.RegistrationDate,
	|	PlatformDumps.DumpOption,
	|	PlatformDumps.PlatformVersion,
	|	PlatformDumps.FileName
	|FROM
	|	InformationRegister.PlatformDumps AS PlatformDumps
	|WHERE
	|	PlatformDumps.FileName <> &FileName";
	
	Query.SetParameter("FileName", "");
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	DumpsToDelete = New Array;
	While SelectionDetailRecords.Next() Do
		DumpToDelete = New Structure;
		DumpToDelete.Insert("RegistrationDate", SelectionDetailRecords.RegistrationDate);
		DumpToDelete.Insert("DumpOption", SelectionDetailRecords.DumpOption);
		DumpToDelete.Insert("PlatformVersion", SelectionDetailRecords.PlatformVersion);
		DumpToDelete.Insert("FileName", SelectionDetailRecords.FileName);
		
		DumpsToDelete.Add(DumpToDelete);
	EndDo;

	Return DumpsToDelete;
EndFunction

Procedure ChangeRecord(Record) Export
	RecordManager = CreateRecordManager();
	RecordManager.RegistrationDate = Record.RegistrationDate;
	RecordManager.DumpOption = Record.DumpOption;
	RecordManager.PlatformVersion = Record.PlatformVersion;
	RecordManager.FileName = Record.FileName;
	RecordManager.Write();
EndProcedure

Function GetRegisteredDumps(Dumps) Export
	Query = New Query;
	Query.Text = 
	"SELECT
	|	PlatformDumps.FileName
	|FROM
	|	InformationRegister.PlatformDumps AS PlatformDumps
	|WHERE
	|	PlatformDumps.FileName IN(&Dumps)";
	
	Query.SetParameter("Dumps", Dumps);
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	HasDumps = New Map;
	While SelectionDetailRecords.Next() Do
		HasDumps.Insert(SelectionDetailRecords.FileName, True);
	EndDo;
	
	Return HasDumps;
EndFunction

Function GetTopOptions(StartDate, EndDate, Count, Val PlatformVersion = Undefined) Export
	StartDateSM = (StartDate - Date(1,1,1)) * 1000;
	EndDateSM = (EndDate - Date(1,1,1)) * 1000;
	
	Query = New Query;
	Query.Text = 
	"SELECT TOP 1000
	|	DumpOption,
	|	OptionsCount
	|FROM
	|	(SELECT
	|		PlatformDumps.DumpOption AS DumpOption,
	|		COUNT(1) AS OptionsCount
	|	FROM
	|		InformationRegister.PlatformDumps AS PlatformDumps
	|	WHERE
	|		PlatformDumps.RegistrationDate BETWEEN &StartDateSM AND &EndDateSM
	|		AND &CondPlatformVersion
	|	GROUP BY
	|		PlatformDumps.DumpOption
	|	) AS Selection
	|ORDER BY
	|	OptionsCount DESC
	|";
		
	Query.Text = StrReplace(Query.Text, "1000", Format(Count, "NG=0"));
	Query.SetParameter("StartDateSM", StartDateSM);
	Query.SetParameter("EndDateSM", EndDateSM);
	If PlatformVersion <> Undefined Then
		PlatformVersionNumber = MonitoringCenterInternal.PlatformVersionToNumber(PlatformVersion);
		Query.Text = StrReplace(Query.Text, "&CondPlatformVersion", "PlatformDumps.PlatformVersion = &PlatformVersion");
		Query.SetParameter("PlatformVersion", PlatformVersionNumber);
	Else
		Query.Text = StrReplace(Query.Text, "&CondPlatformVersion", "TRUE");
	EndIf;
		
	QueryResult = Query.Execute();
	Return QueryResult;
EndFunction

#EndRegion

#EndIf