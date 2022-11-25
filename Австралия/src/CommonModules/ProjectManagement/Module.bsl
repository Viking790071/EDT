#Region Internal

Procedure FillInProjectPhasesCodeWBS(Project) Export
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	ProjectPhases.Ref AS Ref,
	|	ProjectPhases.PhaseNumberInLevel AS PhaseNumberInLevel,
	|	ProjectPhases.DeletionMark AS DeletionMark,
	|	ProjectPhases.CodeWBS AS CodeWBS
	|FROM
	|	Catalog.ProjectPhases AS ProjectPhases
	|WHERE
	|	ProjectPhases.Owner = &Project
	|	AND ProjectPhases.Parent = VALUE(Catalog.ProjectPhases.EmptyRef)
	|
	|ORDER BY
	|	ProjectPhases.PhaseNumberInLevel,
	|	ProjectPhases.Description";
	
	Query.SetParameter("Project", Project);
	
	Result = Query.Execute();
	If Result.IsEmpty() Then
		Return;
	EndIf;
	
	Counter = 1;
	Selection = Result.Select();
	While Selection.Next() Do
		
		If Selection.DeletionMark Then
			CodeWBS = "";
			PhaseNumberInLevel = 9999;
		Else
			CodeWBS = String(Counter);
			PhaseNumberInLevel = Counter;
			
			Counter = Counter + 1;
		EndIf;
		
		If (Selection.PhaseNumberInLevel <> PhaseNumberInLevel) Or (Selection.CodeWBS <> CodeWBS) Then
			
			Try
				LockDataForEdit(Selection.Ref);
			Except
				// If the object has already been locked (with the Lock method or by any other means),
				// the method generates an exception.
			EndTry;
			
			PhaseObject = Selection.Ref.GetObject();
			PhaseObject.PhaseNumberInLevel = PhaseNumberInLevel;
			PhaseObject.CodeWBS = CodeWBS;
			PhaseObject.Write();
			
		EndIf;
		
		FillInCodeWBSOfSubordinatePhases(Selection.Ref);
		
	EndDo;
	
	FillInProjectPhasesOrder(Project);
	
EndProcedure

Procedure FillInCodeWBSOfSubordinatePhases(Parent, ChangedPhases = Undefined) Export
	
	SetPrivilegedMode(True);
	
	If ChangedPhases = Undefined Then
		ChangedPhases = New Array;
	EndIf;
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	ProjectPhases.Ref AS Ref,
	|	ProjectPhases.PhaseNumberInLevel AS PhaseNumberInLevel,
	|	ProjectPhases.DeletionMark AS DeletionMark,
	|	ProjectPhases.CodeWBS AS CodeWBS
	|FROM
	|	Catalog.ProjectPhases AS ProjectPhases
	|WHERE
	|	ProjectPhases.Parent = &Parent
	|
	|ORDER BY
	|	ProjectPhases.PhaseNumberInLevel,
	|	ProjectPhases.Description";
	
	Query.SetParameter("Parent", Parent);
	
	Result = Query.Execute();
	If Result.IsEmpty() Then
		Return;
	EndIf;
	
	ParentCode = Common.ObjectAttributeValue(Parent, "CodeWBS");
	
	Counter = 1;
	Selection = Result.Select();
	While Selection.Next() Do
		
		If Selection.DeletionMark Then
			CodeWBS = "";
			PhaseNumberInLevel = 9999;
		Else
			If Not ValueIsFilled(ParentCode) Then
				CodeWBS = String(Counter);
			Else
				CodeWBS = ParentCode + "." + String(Counter);
			EndIf;
			PhaseNumberInLevel = Counter;
			
			Counter = Counter + 1;
		EndIf;
		
		If Selection.PhaseNumberInLevel <> PhaseNumberInLevel Or Selection.CodeWBS <> CodeWBS Then
			
			Try
				LockDataForEdit(Selection.Ref);
			Except
				// If the object has already been locked (with the Lock method or by any other means),
				// the method generates an exception.
			EndTry;
			
			PhaseObject = Selection.Ref.GetObject();
			PhaseObject.PhaseNumberInLevel = PhaseNumberInLevel;
			PhaseObject.CodeWBS = CodeWBS; 
			PhaseObject.Write();
			
			ChangedPhases.Add(PhaseObject.Ref);
			
		EndIf;
		
		FillInCodeWBSOfSubordinatePhases(Selection.Ref, ChangedPhases);
		
	EndDo;
	
EndProcedure

Function GetMaxPhaseNumberInLevel(Project, Parent) Export
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	ISNULL(MAX(ProjectPhases.PhaseNumberInLevel), 0) AS PhaseNumberInLevel
	|FROM
	|	Catalog.ProjectPhases AS ProjectPhases
	|WHERE
	|	ProjectPhases.Owner = &Project
	|	AND ProjectPhases.Parent = &Parent
	|	AND NOT ProjectPhases.DeletionMark";
	
	Query.SetParameter("Parent", Parent);
	Query.SetParameter("Project", Project);
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		Return Selection.PhaseNumberInLevel;
	EndIf;
	
	Return 0;
	
EndFunction

Function GetPhasesSameLevelPhases(Project, Phase) Export
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	ProjectPhases.Ref AS Ref
	|FROM
	|	Catalog.ProjectPhases AS ProjectPhases
	|WHERE
	|	ProjectPhases.Owner = &Project
	|	AND ProjectPhases.Parent = &Parent
	|	AND NOT ProjectPhases.DeletionMark";
	
	Parent = Common.ObjectAttributeValue(Phase, "Parent");
	
	Query.SetParameter("Parent", Parent);
	Query.SetParameter("Project", Project);
	
	Return Query.Execute().Unload().UnloadColumn("Ref");
	
EndFunction

Function GetCodeWBSAndPhaseNumberInLevel(Project, Parent) Export
	
	MaxNumber = GetMaxPhaseNumberInLevel(Project, Parent);
	
	CodeWBSString = "";
	If ValueIsFilled(Parent) Then
		CodeWBSString = Parent.CodeWBS;
	EndIf;
	
	PhaseNumberInLevel = MaxNumber + 1;
	CodeWBS = CodeWBSString + ?(ValueIsFilled(CodeWBSString), ".", "") + String(PhaseNumberInLevel);
	
	DataStructure = New Structure;
	DataStructure.Insert("CodeWBS", CodeWBS);
	DataStructure.Insert("PhaseNumberInLevel", PhaseNumberInLevel);
	
	Return DataStructure;
	
EndFunction

Function CalculatePeriodEnd(Val ProjectPhase, StartDate, Duration, DurationUnit) Export
	
	ProjectAttributes = Common.ObjectAttributesValues(ProjectPhase.Owner,
		"WorkSchedule, DurationUnit, UseWorkSchedule");
	
	If Not ValueIsFilled(DurationUnit) Then 
		DurationUnit = ProjectAttributes.DurationUnit;
	EndIf;
	
	If Not ValueIsFilled(Duration) Then 
		Return StartDate;
	EndIf;
	
	DurationHour = RecalculateDuration(Duration,
		DurationUnit,
		Enums.DurationUnits.Hour,
		ProjectAttributes.UseWorkSchedule,
		ProjectAttributes.WorkSchedule);
	
	If ProjectAttributes.UseWorkSchedule Then
		EndDate = WorkSchedulesDrive.GetPeriodEndDateSec(ProjectAttributes.WorkSchedule, StartDate, DurationHour * 3600); 
	Else
		EndDate = StartDate + DurationHour * 3600;
	EndIf;
	
	Return EndDate;
	
EndFunction

Function CalculatePeriodDuration(Val ProjectPhase, StartDate, EndDate, DurationUnit) Export
	
	ProjectAttributes = Common.ObjectAttributesValues(ProjectPhase.Owner,
		"WorkSchedule, DurationUnit, UseWorkSchedule");
	
	If Not ValueIsFilled(DurationUnit) Then
		DurationUnit = ProjectAttributes.DurationUnit;
	EndIf;
	
	If Not ValueIsFilled(StartDate)
		Or Not ValueIsFilled(EndDate)
		Or StartDate > EndDate Then
		Return 0;
	EndIf;
	
	If ProjectAttributes.UseWorkSchedule Then
		DurationSec = WorkSchedulesDrive.GetPeriodDurationSec(ProjectAttributes.WorkSchedule, StartDate, EndDate);
	Else
		DurationSec = EndDate - StartDate;
	EndIf;
	
	DurationHour = DurationSec / 3600;
	
	Duration = RecalculateDuration(DurationHour,
		Enums.DurationUnits.Hour,
		DurationUnit,
		ProjectAttributes.UseWorkSchedule,
		ProjectAttributes.WorkSchedule);
	
	Return Duration;
	
EndFunction

Function CalculatePeriodStart(Val ProjectPhase, EndDate, Duration, DurationUnit) Export
	
	ProjectAttributes = Common.ObjectAttributesValues(ProjectPhase.Owner,
		"WorkSchedule, DurationUnit, UseWorkSchedule");
	
	If Not ValueIsFilled(DurationUnit) Then
		DurationUnit = ProjectAttributes.DurationUnit;
	EndIf;
	
	If Not ValueIsFilled(Duration) Then
		Return EndDate;
	EndIf;
	
	DurationHour = RecalculateDuration(Duration,
		DurationUnit,
		Enums.DurationUnits.Hour,
		ProjectAttributes.UseWorkSchedule,
		ProjectAttributes.WorkSchedule);
	
	If ProjectAttributes.UseWorkSchedule Then
		StartDate = WorkSchedulesDrive.GetPeriodStartDateSec(ProjectAttributes.WorkSchedule, EndDate, DurationHour * 3600);
	Else
		StartDate = EndDate - DurationHour * 3600;
	EndIf;
	
	Return StartDate;
	
EndFunction

Procedure CalculatePlanOfEntireProject(Project) Export
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	ProjectPhases.Ref AS Ref
	|FROM
	|	Catalog.ProjectPhases AS ProjectPhases
	|WHERE
	|	ProjectPhases.Owner = &Project
	|	AND NOT ProjectPhases.DeletionMark
	|	AND NOT ProjectPhases.SummaryPhase
	|	AND ProjectPhases.PreviousPhase = VALUE(Catalog.ProjectPhases.EmptyRef)";
	
	Query.SetParameter("Project", Project);
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		CalculateProjectPlan(Selection.Ref);
	EndDo;
	
EndProcedure

Procedure CalculateProjectPlan(ProjectPhase, ModifiedPhasesArray = Undefined) Export
	
	ProjectPhaseOwner = Common.ObjectAttributeValue(ProjectPhase, "Owner");
	
	ProjectData = GetProjectData(ProjectPhaseOwner);
	
	If ModifiedPhasesArray = Undefined Then
		ModifiedPhasesArray = New Array;
	EndIf;
	
	RecalculatePlanByPhase = True;
	
	CalculateProjectPlanByPhase(ProjectPhase, RecalculatePlanByPhase, ModifiedPhasesArray, ProjectData);
	
	For Each Row In ProjectData Do
		
		If Row.Value.Modified Then
			
			DataStructure = New Structure;
			DataStructure.Insert("StartDate", Row.Value.StartDate);
			DataStructure.Insert("EndDate", Row.Value.EndDate);
			DataStructure.Insert("Duration", Row.Value.Duration);
			DataStructure.Insert("ActualStartDate", Row.Value.ActualStartDate);
			DataStructure.Insert("ActualEndDate", Row.Value.ActualEndDate);
			DataStructure.Insert("ActualDuration", Row.Value.ActualDuration);
			
			WriteProjectPhaseTimelines(Row.Key, DataStructure);
			
		EndIf;
		
	EndDo;
	
EndProcedure

Function IsSummaryPhase(ProjectPhase) Export
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	TRUE AS VrtField
	|FROM
	|	Catalog.ProjectPhases AS ProjectPhases
	|WHERE
	|	ProjectPhases.Parent = &ProjectPhase
	|	AND NOT ProjectPhases.DeletionMark";
	
	Query.SetParameter("ProjectPhase", ProjectPhase);
	Result = Query.Execute();
	
	Return Not Result.IsEmpty();
	
EndFunction

Function GetAllNextPhases(ProjectPhase, IncludeEndOfProject = True) Export
	
	SetPrivilegedMode(True);
	
	PhaseList = New ValueList;
	
	CurParent = ProjectPhase;
	While ValueIsFilled(CurParent) Do
		PhaseList.Add(CurParent);
		CurParent = CurParent.Parent;
	EndDo;
	
	Query = New Query;
	Query.Text = 
	"SELECT DISTINCT
	|	ProjectPhases.Ref AS Ref,
	|	ProjectPhases.SummaryPhase AS SummaryPhase,
	|	ProjectPhasesTimelines.StartDate AS StartDate,
	|	ProjectPhasesTimelines.EndDate AS EndDate
	|FROM
	|	Catalog.ProjectPhases AS ProjectPhases
	|		LEFT JOIN InformationRegister.ProjectPhasesTimelines AS ProjectPhasesTimelines
	|		ON ProjectPhases.Ref = ProjectPhasesTimelines.ProjectPhase
	|WHERE
	|	ProjectPhases.PreviousPhase IN(&PhaseList)
	|	AND NOT ProjectPhases.DeletionMark";
	
	Query.SetParameter("PhaseList", PhaseList);
	
	Result = Query.Execute().Unload();
	
	AllNext = Result.Copy();
	AllNext.Clear();
	
	For Each Row In Result Do
		
		If Row.SummaryPhase Then
			
			SubordinatesPhases = GetAllSubordinatesPhases(Row.Ref);
			For Each SubordinatePhase In SubordinatesPhases Do
				
				If SubordinatePhase.SummaryPhase Then
					Continue;
				EndIf;
				
				NewRow = AllNext.Add();
				NewRow.Ref = SubordinatePhase.Ref;
				NewRow.SummaryPhase = SubordinatePhase.SummaryPhase;
				NewRow.StartDate = SubordinatePhase.StartDate;
				NewRow.EndDate = SubordinatePhase.EndDate;
				
			EndDo;
			
		Else
			
			NewRow = AllNext.Add();
			FillPropertyValues(NewRow, Row);
			
		EndIf;
		
	EndDo;
	
	If IncludeEndOfProject Then 
		
		ProjectEnd = Common.ObjectAttributeValue(ProjectPhase.Owner, "EndDate");
		If AllNext.Count() = 0 Then 
			NewRow = AllNext.Add();
			NewRow.Ref = ProjectPhase;
			NewRow.StartDate = ProjectEnd;
			NewRow.EndDate = ProjectEnd;
		EndIf;
		
	EndIf;
	
	Return AllNext;
	
EndFunction

Procedure CheckPreviousPhase(ProjectPhase) Export
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	ProjectPhases.Ref AS Ref
	|FROM
	|	Catalog.ProjectPhases AS ProjectPhases
	|WHERE
	|	ProjectPhases.Ref = &ProjectPhase
	|	AND NOT ProjectPhases.DeletionMark
	|TOTALS BY
	|	Ref ONLY HIERARCHY";
	
	Query.SetParameter("ProjectPhase", ProjectPhase);
	
	Selection = Query.Execute().Select();
	ProjectPhasesParents = New ValueList();
	
	While Selection.Next() Do
		If ValueIsFilled(Selection.Ref)
			And ProjectPhasesParents.FindByValue(Selection.Ref) = Undefined Then
			ProjectPhasesParents.Add(Selection.Ref);
		EndIf;
	EndDo;
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	ProjectPhases.Ref AS Ref
	|FROM
	|	Catalog.ProjectPhases AS ProjectPhases
	|WHERE
	|	ProjectPhases.Ref IN HIERARCHY(&ProjectPhase)
	|	AND NOT ProjectPhases.DeletionMark
	|TOTALS BY
	|	Ref ONLY HIERARCHY";
	
	Query.SetParameter("ProjectPhase", ProjectPhase);
	
	Selection = Query.Execute().Select();
	ProjectPhasesSubordinates = New ValueList();
	
	While Selection.Next() Do
		If ValueIsFilled(Selection.Ref)
			And ProjectPhasesSubordinates.FindByValue(Selection.Ref) = Undefined Then
			ProjectPhasesSubordinates.Add(Selection.Ref);
		EndIf;
	EndDo;
	
	PreviousPhase = Common.ObjectAttributeValue(ProjectPhase, "PreviousPhase");
	
	If PreviousPhase = ProjectPhase Then
		Raise(NStr("en = 'Cannot save this phase. Previous phase is set to this phase. Select another previous phase.'; ru = 'Не удалось сохранить этап. Предыдущим этапом назначен данный этап. Выберите другой предыдущий этап.';pl = 'Nie można zapisać tego etapu. Poprzedni etap jest ustawiony na ten etap. Wybierz inny poprzedni etap.';es_ES = 'No se ha podido guardar esta fase. La fase anterior está establecida en esta fase. Seleccione otra fase anterior.';es_CO = 'No se ha podido guardar esta fase. La fase anterior está establecida en esta fase. Seleccione otra fase anterior.';tr = 'Bu evre kaydedilemiyor. Önceki evre bu evreye ayarlı. Başka bir önceki evre seçin.';it = 'Impossibile salvare questa fase. La fase precedente è impostata su questa fase. Seleziona un''altra fase precedente.';de = 'Fehler beim Speichern dieser Phase. Die vorherige Phase ist zu dieser Phase gesetzt. Wählen Sie eine andere vorherige Phase aus.'"));
	EndIf;
	
	If ProjectPhasesParents.FindByValue(PreviousPhase) <> Undefined Then
		Raise(NStr("en = 'Cannot save this phase. Previous phase is set to a phase
					|that this phase is subordinate to. Select another previous phase.'; 
					|ru = 'Не удалось сохранить этап. Предыдущим этапом назначен этап,
					|которому подчинен данный этап. Выберите другой предыдущий этап.';
					|pl = 'Nie można zapisać tego etapu. Poprzedni etap jest ustawiony na etap,
					|w stosunku do którego ten etap jest podrzędny. Wybierz inny poprzedni etap.';
					|es_ES = 'No se ha podido guardar esta fase. La fase anterior está establecida
					|en una fase a la que esta fase está subordinada. Seleccione otra fase anterior.';
					|es_CO = 'No se ha podido guardar esta fase. La fase anterior está establecida
					|en una fase a la que esta fase está subordinada. Seleccione otra fase anterior.';
					|tr = 'Bu evre kaydedilemiyor. Önceki evre, bu evrenin bağlı olduğu
					|bir evreye ayarlı. Başka bir önceki evre seçin.';
					|it = 'Impossibile salvare questa fase. La fase precedente è impostata su una fase
					|a cui questa è subordinata. Seleziona un''altra fase precedente.';
					|de = 'Fehler beim Speichern dieser Phase. Die vorherige Phase ist zu einer Phase
					| die dieser Phase untergeordnet ist, gesetzt. Wählen Sie eine andere vorherige Phase aus.'"));
	EndIf;
	
	If ProjectPhasesSubordinates.FindByValue(PreviousPhase) <> Undefined Then
		Raise(NStr("en = 'Cannot save this phase. Previous phase is set to a phase
					|subordinate to this phase. Select another previous phase.'; 
					|ru = 'Не удалось сохранить этап. Предыдущим этапом назначен этап,
					|подчиненный данному этапу. Выберите другой предыдущий этап.';
					|pl = 'Nie można zapisać tego etapu. Poprzedni etap jest ustawiony na etap,
					|podrzędny do tego etapu. Wybierz inny poprzedni etap.';
					|es_ES = 'No se ha podido guardar esta fase. La fase anterior está establecida en una fase
					|subordinada a esta fase. Seleccione otra fase anterior.';
					|es_CO = 'No se ha podido guardar esta fase. La fase anterior está establecida en una fase
					|subordinada a esta fase. Seleccione otra fase anterior.';
					|tr = 'Bu evre kaydedilemiyor. Önceki evre, bu evreye bağlı
					|bir evreye ayarlı. Başka bir önceki evre seçin.';
					|it = 'Impossibile salvare questa fase. La fase precedente è impostata su una fase
					|subordinata a questa. Seleziona un''altra fase precedente.';
					|de = 'Fehler beim Speichern dieser Phase. Die vorherige Phase ist zu einer Phase
					| der diese Phase untergeordnet ist, gesetzt. Wählen Sie eine andere vorherige Phase aus.'"))
	EndIf;
	
	PhasesProcessed = New Array;
	PhasesInProcessing = New Array;
	
	CheckPredecessorsForLooping(ProjectPhase, PhasesInProcessing, PhasesProcessed);
	
	For Each Row In ProjectPhasesSubordinates Do
		
		PhasesProcessed = New Array;
		PhasesInProcessing = New Array;
		
		CheckPredecessorsForLooping(Row.Value, PhasesInProcessing, PhasesProcessed);
		
	EndDo;
	
EndProcedure

Function GenerateProjectPhaseChoiceData(Text, Project) Export
	
	ChoiceData = New ValueList;
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	ProjectPhases.Ref AS Ref,
	|	ProjectPhases.CodeWBS AS CodeWBS,
	|	ProjectPhases.Description AS Description
	|FROM
	|	Catalog.ProjectPhases AS ProjectPhases
	|WHERE
	|	ProjectPhases.Owner = &Project
	|	AND ProjectPhases.Description LIKE &Text
	|	AND NOT ProjectPhases.DeletionMark
	|
	|UNION
	|
	|SELECT
	|	ProjectPhases.Ref,
	|	ProjectPhases.CodeWBS,
	|	ProjectPhases.Description
	|FROM
	|	Catalog.ProjectPhases AS ProjectPhases
	|WHERE
	|	ProjectPhases.Owner = &Project
	|	AND ProjectPhases.CodeWBS LIKE &Text
	|	AND NOT ProjectPhases.DeletionMark";
	
	Query.SetParameter("Project", Project);
	Query.SetParameter("Text", Text+"%");
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		ChoiceData.Add(Selection.Ref, Selection.CodeWBS + " " + Selection.Description);
	EndDo;
	
	Return ChoiceData;
	
EndFunction

Function ExistProjectPhases(Project) Export
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text = 
	"SELECT TOP 1
	|	TRUE AS VrtField
	|FROM
	|	Catalog.ProjectPhases AS ProjectPhases
	|WHERE
	|	ProjectPhases.Owner = &Project
	|	AND NOT ProjectPhases.DeletionMark";
	
	Query.SetParameter("Project", Project);
	
	Return Not Query.Execute().IsEmpty();
	
EndFunction

Function ExistNotCompetedProjectPhases(Project) Export
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text = 
	"SELECT TOP 1
	|	TRUE AS VrtField
	|FROM
	|	Catalog.ProjectPhases AS ProjectPhases
	|		LEFT JOIN InformationRegister.ProjectPhasesTimelines AS ProjectPhasesTimelines
	|		ON ProjectPhases.Ref = ProjectPhasesTimelines.ProjectPhase
	|WHERE
	|	ProjectPhases.Owner = &Project
	|	AND NOT ProjectPhases.DeletionMark
	|	AND ProjectPhasesTimelines.ActualEndDate = DATETIME(1, 1, 1)";
	
	Query.SetParameter("Project", Project);
	
	Return Not Query.Execute().IsEmpty();
	
EndFunction

Function GetProjectPhasesData(ProjectPhases) Export
	
	SetPrivilegedMode(True);
	
	DataMap = New Map;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	ProjectPhases.Ref AS Ref,
	|	ProjectPhases.Owner AS Project,
	|	ProjectPhases.Parent AS Parent,
	|	ProjectPhases.SummaryPhase AS SummaryPhase,
	|	ProjectPhases.Owner AS Owner,
	|	ProjectPhases.Description AS Description,
	|	ProjectPhases.CodeWBS AS CodeWBS,
	|	ProjectPhases.DataVersion AS DataVersion,
	|	ProjectPhases.DeletionMark AS DeletionMark,
	|	ProjectPhases.Executor AS Executor,
	|	ProjectPhases.PreviousPhase AS PreviousPhase,
	|	ProjectPhases.Status AS Status,
	|	Projects.WorkSchedule AS WorkSchedule,
	|	Projects.CalculateDeadlinesAutomatically AS CalculateDeadlinesAutomatically,
	|	ISNULL(ProjectPhasesTimelines.StartDate, DATETIME(1, 1, 1)) AS StartDate,
	|	ISNULL(ProjectPhasesTimelines.EndDate, DATETIME(1, 1, 1)) AS EndDate,
	|	ISNULL(ProjectPhasesTimelines.Duration, 0) AS Duration,
	|	ISNULL(ProjectPhasesTimelines.DurationUnit, VALUE(Enum.DurationUnits.EmptyRef)) AS DurationUnit,
	|	ISNULL(ProjectPhasesTimelines.ActualStartDate, DATETIME(1, 1, 1)) AS ActualStartDate,
	|	ISNULL(ProjectPhasesTimelines.ActualEndDate, DATETIME(1, 1, 1)) AS ActualEndDate,
	|	ISNULL(ProjectPhasesTimelines.ActualDuration, 0) AS ActualDuration,
	|	ISNULL(ProjectPhasesTimelines.ActualDurationUnit, VALUE(Enum.DurationUnits.EmptyRef)) AS ActualDurationUnit
	|FROM
	|	Catalog.Projects AS Projects
	|		INNER JOIN Catalog.ProjectPhases AS ProjectPhases
	|		ON Projects.Ref = ProjectPhases.Owner
	|		LEFT JOIN InformationRegister.ProjectPhasesTimelines AS ProjectPhasesTimelines
	|		ON (ProjectPhases.Ref = ProjectPhasesTimelines.ProjectPhase)
	|WHERE
	|	ProjectPhases.Ref IN(&ProjectPhases)";
	
	Query.SetParameter("ProjectPhases", ProjectPhases);
	Query.SetParameter("CurrentDate", BegOfDay(CurrentSessionDate()));
	
	QueryResultTable = Query.Execute().Unload();
	
	For Each ProjectPhase In ProjectPhases Do
		
		Result = New Structure;
		Result.Insert("Ref", Catalogs.ProjectPhases.EmptyRef());
		Result.Insert("Project", Catalogs.Projects.EmptyRef());
		Result.Insert("Parent", Catalogs.ProjectPhases.EmptyRef());
		Result.Insert("SummaryPhase", False);
		Result.Insert("CodeWBS", "");
		Result.Insert("DataVersion", "");
		Result.Insert("DeletionMark", False);
		Result.Insert("Description", "");
		Result.Insert("Owner", Catalogs.Projects.EmptyRef());
		Result.Insert("WorkSchedule", Catalogs.WorkSchedules.EmptyRef());
		Result.Insert("CalculateDeadlinesAutomatically", False);
		Result.Insert("StartDate", '00010101');
		Result.Insert("EndDate", '00010101');
		Result.Insert("Duration", 0);
		Result.Insert("DurationUnit", Enums.DurationUnits.EmptyRef());
		Result.Insert("ActualStartDate", '00010101');
		Result.Insert("ActualEndDate", '00010101');
		Result.Insert("ActualDuration", 0);
		Result.Insert("ActualDurationUnit", Enums.DurationUnits.EmptyRef());
		Result.Insert("Executor", Catalogs.Users.EmptyRef());
		Result.Insert("PreviousPhase", Catalogs.ProjectPhases.EmptyRef());
		Result.Insert("Status", Enums.ProjectPhaseStatuses.Open);
		
		FoundRow = QueryResultTable.Find(ProjectPhase, "Ref");
		If FoundRow <> Undefined And ValueIsFilled(ProjectPhase) Then
			
			FillPropertyValues(Result, FoundRow);
			
		EndIf;
		
		DataMap.Insert(ProjectPhase, Result);
		
	EndDo;
	
	Return DataMap;
	
EndFunction

Function GetPhaseData(ProjectPhase) Export
	
	ProjectPhases = New Array;
	ProjectPhases.Add(ProjectPhase);
	
	DataMap = GetProjectPhasesData(ProjectPhases);
	
	Return DataMap.Get(ProjectPhase);
	
EndFunction

Function GetProjectPhaseTimelines(ProjectPhase) Export
	
	SetPrivilegedMode(True);
	
	DataStructure = New Structure;
	DataStructure.Insert("StartDate", '00010101');
	DataStructure.Insert("EndDate", '00010101');
	DataStructure.Insert("Duration", 0);
	DataStructure.Insert("DurationUnit", Enums.DurationUnits.EmptyRef());
	DataStructure.Insert("ActualStartDate", '00010101');
	DataStructure.Insert("ActualEndDate", '00010101');
	DataStructure.Insert("ActualDuration", 0);
	DataStructure.Insert("ActualDurationUnit", Enums.DurationUnits.EmptyRef());
	
	If ValueIsFilled(ProjectPhase) Then
		
		RecordManager = InformationRegisters.ProjectPhasesTimelines.CreateRecordManager();
		RecordManager.ProjectPhase = ProjectPhase;
		RecordManager.Read();
		
		If RecordManager.Selected() Then
			FillPropertyValues(DataStructure, RecordManager);
		EndIf;
		
	EndIf;
	
	Return DataStructure;
	
EndFunction

Procedure WriteProjectPhaseTimelines(ProjectPhase, DataStructure) Export
	
	SetPrivilegedMode(True);
	
	RecordChanged = False;
	
	RecordManager = InformationRegisters.ProjectPhasesTimelines.CreateRecordManager();
	RecordManager.ProjectPhase = ProjectPhase;
	RecordManager.Read();
	
	If Not RecordManager.Selected() Then
		RecordManager.ProjectPhase = ProjectPhase;
		RecordChanged = True;
	EndIf;
	
	For Each Row In DataStructure Do
		If RecordManager[Row.Key] <> Row.Value Then
			RecordManager[Row.Key] = Row.Value;
			RecordChanged = True;
		EndIf;
	EndDo;
	
	If RecordChanged Then
		RecordManager.Write();
	EndIf;
	
EndProcedure

Procedure FillInProjectPhasesOrder(Project) Export
	
	SetPrivilegedMode(True);
	
	ProjectPhaseNumber = 1;
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	ProjectPhases.Ref AS Ref
	|FROM
	|	Catalog.ProjectPhases AS ProjectPhases
	|WHERE
	|	ProjectPhases.Owner = &Project
	|	AND ProjectPhases.Parent = VALUE(Catalog.ProjectPhases.EmptyRef)
	|
	|ORDER BY
	|	ProjectPhases.PhaseNumberInLevel,
	|	ProjectPhases.Description";
	
	Query.SetParameter("Project", Project);
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		
		InformationRegisters.ProjectPhasesOrder.SetProjectPhaseOrder(Selection.Ref, ProjectPhaseNumber);
		
		ProjectPhaseNumber = ProjectPhaseNumber + 1;
		
		FillInSubordinatePhasesOrder(Selection.Ref, ProjectPhaseNumber);
		
	EndDo;
	
EndProcedure

Function HaveNoOwnProjects(User) Export
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	TRUE AS VrtField
	|FROM
	|	Catalog.Projects AS Projects
	|WHERE
	|	Projects.Manager = &User
	|	AND NOT Projects.DeletionMark";
	
	Query.SetParameter("User", User);
	
	Return Query.Execute().IsEmpty();
	
EndFunction

Function CheckProjectPhaseNewStatus(NewStatus, PhaseRef) Export
	
	Result = New Structure;
	Result.Insert("Checked", True);
	Result.Insert("MessageText", "");
	Result.Insert("IsQuery", False);
	
	If ValueIsFilled(PhaseRef) Then
		PrevStatus = Common.ObjectAttributeValue(PhaseRef, "Status");
		If Not ValueIsFilled(PrevStatus) Then
			PrevStatus = Enums.ProjectPhaseStatuses.Open;
		EndIf;
	Else
		PrevStatus = Enums.ProjectPhaseStatuses.Open;
	EndIf;
	
	Result.Insert("PrevStatus", PrevStatus);
	
	If NewStatus = PrevStatus Then
		Return Result;
	EndIf;
	
	SetPrivilegedMode(True);
	
	If PrevStatus = Enums.ProjectPhaseStatuses.Open
		And NewStatus = Enums.ProjectPhaseStatuses.Completed
		Or PrevStatus = Enums.ProjectPhaseStatuses.Completed
		And NewStatus = Enums.ProjectPhaseStatuses.Open Then
		
		Result.MessageText = NStr("en = 'First, change status to In progress. Then try again.'; ru = 'Поменяйте статус на ""В работе"" и повторите попытку.';pl = 'Najpierw, zmień status na W toku. Następnie spróbuj ponownie.';es_ES = 'Primero, cambie el estado a En progreso. Inténtelo de nuevo.';es_CO = 'Primero, cambie el estado a En progreso. Inténtelo de nuevo.';tr = 'Durumu İşlemde olarak değiştirip tekrar deneyin.';it = 'Prima cambio lo stato a In lavorazione. Poi riprova.';de = 'Ändern Sie den Status für In Bearbeitung zuerst. Dann versuchen Sie erneut.'");
		Result.Checked = False;
		
	ElsIf PrevStatus = Enums.ProjectPhaseStatuses.InProgress Then
		
		If NewStatus = Enums.ProjectPhaseStatuses.Open Then
			
			Query = New Query;
			Query.Text = 
			"SELECT TOP 1
			|	TRUE AS VrtField
			|FROM
			|	Task.PerformerTask AS PerformerTask
			|WHERE
			|	PerformerTask.ProjectPhase = &ProjectPhase
			|	AND NOT PerformerTask.DeletionMark";
			
			Query.SetParameter("ProjectPhase", PhaseRef);
			
			QueryResult = Query.Execute();
			If Not QueryResult.IsEmpty() Then
				Result.MessageText = NStr("en = 'Cannot change the status. The phase already has tasks.'; ru = 'Не удалось изменить статус. Для этапа уже созданы задачи.';pl = 'Nie można zmienić statusu. Etap już ma zadania.';es_ES = 'No se ha podido modificar el estado. La fase dispone ya de tareas.';es_CO = 'No se ha podido modificar el estado. La fase dispone ya de tareas.';tr = 'Durum değiştirilemiyor. Bu evrede görevler var.';it = 'Impossibile cambiare lo stato. Nella fase sono già presenti dei compiti.';de = 'Fehler beim Ändern des Status. Die Phase hat bereits Aufgaben.'");
				Result.Checked = False;
			EndIf;
			
		ElsIf NewStatus = Enums.ProjectPhaseStatuses.Completed Then
			
			Query = New Query;
			Query.Text = 
			"SELECT TOP 1
			|	TRUE AS VrtField
			|FROM
			|	Task.PerformerTask AS PerformerTask
			|WHERE
			|	PerformerTask.ProjectPhase = &ProjectPhase
			|	AND NOT PerformerTask.DeletionMark
			|	AND NOT PerformerTask.Executed";
			
			Query.SetParameter("ProjectPhase", PhaseRef);
			
			QueryResult = Query.Execute();
			If Not QueryResult.IsEmpty() Then
				Result.MessageText = NStr("en = 'The phase has tasks pending completion.
					|If you continue, they will be completed automatically. Continue?'; 
					|ru = 'В этапе есть задачи, ожидающие завершения.
					|Если вы продолжите, они будут завершены автоматически. Продолжить?';
					|pl = 'Etap ma etapy w toku wykonania.
					|W przypadku kontynuowania, zostaną zakończone automatycznie. Kontynuować?';
					|es_ES = 'La fase tiene tareas pendientes de finalizar.
					|Si continúa, se finalizarán automáticamente. ¿Continuar?';
					|es_CO = 'La fase tiene tareas pendientes de finalizar.
					|Si continúa, se finalizarán automáticamente. ¿Continuar?';
					|tr = 'Bu evrede tamamlanmamış görevler var.
					|Devam ederseniz bunlar otomatik olarak tamamlanacak. Devam etmek istiyor musunuz?';
					|it = 'La fase ha compiti in attesa di completamento.
					|Continuando, i compiti verranno completati automaticamente. Continuare?';
					|de = 'Die Phase hat Aufgaben mit anstehendem Abschluss.
					|Wenn Sie fortfahren, werden sie automatisch abgeschlossen. Fortfahren?'");
				Result.Checked = False;
				Result.IsQuery = True;
			EndIf;
			
		EndIf;
		
	EndIf;
	
	Return Result;
	
EndFunction

Function CheckProjectNewStatus(NewStatus, ProjectRef) Export
	
	Result = New Structure;
	Result.Insert("Checked", True);
	Result.Insert("MessageText", "");
	Result.Insert("IsQuery", False);
	
	If ValueIsFilled(ProjectRef) Then
		PrevStatus = Common.ObjectAttributeValue(ProjectRef, "Status");
		If Not ValueIsFilled(PrevStatus) Then
			PrevStatus = Enums.ProjectStatuses.Open;
		EndIf;
	Else
		PrevStatus = Enums.ProjectStatuses.Open;
	EndIf;
	
	Result.Insert("PrevStatus", PrevStatus);
	
	If NewStatus = PrevStatus Then
		Return Result;
	EndIf;
	
	SetPrivilegedMode(True);
	
	If PrevStatus = Enums.ProjectStatuses.Open
		And NewStatus = Enums.ProjectStatuses.Completed
		Or PrevStatus = Enums.ProjectStatuses.Completed
		And NewStatus = Enums.ProjectStatuses.Open Then
		
		Result.MessageText = NStr("en = 'First, change status to In progress. Then try again.'; ru = 'Поменяйте статус на ""В работе"" и повторите попытку.';pl = 'Najpierw, zmień status na W toku. Następnie spróbuj ponownie.';es_ES = 'Primero, cambie el estado a En progreso. Inténtelo de nuevo.';es_CO = 'Primero, cambie el estado a En progreso. Inténtelo de nuevo.';tr = 'Durumu İşlemde olarak değiştirip tekrar deneyin.';it = 'Prima cambio lo stato a In lavorazione. Poi riprova.';de = 'Ändern Sie den Status für In Bearbeitung zuerst. Dann versuchen Sie erneut.'");
		Result.Checked = False;
		
	ElsIf PrevStatus = Enums.ProjectStatuses.InProgress Then
		
		If NewStatus = Enums.ProjectStatuses.Open Then
			
			Query = New Query;
			Query.Text = 
			"SELECT TOP 1
			|	TRUE AS VrtField
			|FROM
			|	Task.PerformerTask AS PerformerTask
			|WHERE
			|	PerformerTask.Project = &Project
			|	AND NOT PerformerTask.DeletionMark";
			
			Query.SetParameter("Project", ProjectRef);
			
			QueryResult = Query.Execute();
			If Not QueryResult.IsEmpty() Then
				Result.MessageText = NStr("en = 'Cannot change the status. The project already has tasks.'; ru = 'Не удалось изменить статус. Для проекта уже созданы задачи.';pl = 'Nie można zmienić statusu. Projekt już ma zadania.';es_ES = 'No se ha podido modificar el estado. El proyecto dispone ya de tareas.';es_CO = 'No se ha podido modificar el estado. El proyecto dispone ya de tareas.';tr = 'Durum değiştirilemiyor. Bu projede görevler var.';it = 'Impossibile cambiare lo stato. Nel progetto sono già presenti dei compiti.';de = 'Fehler beim Ändern des Status. Das Projekt hat bereits Aufgaben.'");
				Result.Checked = False;
			EndIf;
			
		ElsIf NewStatus = Enums.ProjectStatuses.Completed Then
			
			Query = New Query;
			Query.Text = 
			"SELECT TOP 1
			|	TRUE AS VrtField
			|FROM
			|	Task.PerformerTask AS PerformerTask
			|WHERE
			|	PerformerTask.Project = &Project
			|	AND NOT PerformerTask.DeletionMark
			|	AND NOT PerformerTask.Executed";
			
			Query.SetParameter("Project", ProjectRef);
			
			QueryResult = Query.Execute();
			If Not QueryResult.IsEmpty() Then
				Result.MessageText = NStr("en = 'The project has tasks pending completion.
					|If you continue, they will be completed automatically. Continue?'; 
					|ru = 'В проекте есть задачи, ожидающие завершения.
					|Если вы продолжите, они будут завершены автоматически. Продолжить?';
					|pl = 'Projekt ma zadania w toku wykonania.
					|W przypadku kontynuowania, zostaną zakończone automatycznie. Kontynuować?';
					|es_ES = 'El proyecto tiene tareas pendientes de finalizar.
					|Si continúa, se finalizarán automáticamente. ¿Continuar?';
					|es_CO = 'El proyecto tiene tareas pendientes de finalizar.
					|Si continúa, se finalizarán automáticamente. ¿Continuar?';
					|tr = 'Bu projede tamamlanmamış görevler var.
					|Devam ederseniz bunlar otomatik olarak tamamlanacak. Devam etmek istiyor musunuz?';
					|it = 'Il progetto ha compiti in attesa di completamento.
					|Continuando, i compiti verranno completati automaticamente. Continuare?';
					|de = 'Das Projekt hat Aufgaben mit anstehendem Abschluss.
					|Wenn Sie fortfahren, werden sie automatisch abgeschlossen. Fortfahren?'");
				Result.Checked = False;
				Result.IsQuery = True;
			EndIf;
			
		EndIf;
		
	EndIf;
	
	Return Result;
	
EndFunction

Procedure CompleteProjectPhaseTasks(Ref) Export
	
	If TypeOf(Ref) = Type("CatalogRef.ProjectPhases") Then
		
		QueryText = 
		"SELECT
		|	PerformerTask.Ref AS Ref
		|FROM
		|	Task.PerformerTask AS PerformerTask
		|WHERE
		|	PerformerTask.ProjectPhase = &Ref
		|	AND NOT PerformerTask.DeletionMark
		|	AND NOT PerformerTask.Executed";
		
	ElsIf TypeOf(Ref) = Type("CatalogRef.Projects") Then
		
		QueryText = 
		"SELECT
		|	PerformerTask.Ref AS Ref
		|FROM
		|	Task.PerformerTask AS PerformerTask
		|WHERE
		|	PerformerTask.Project = &Ref
		|	AND NOT PerformerTask.DeletionMark
		|	AND NOT PerformerTask.Executed";
		
	Else
		
		Return;
		
	EndIf;
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("Ref", Ref);
	
	QueryResult = Query.Execute();
	If Not QueryResult.IsEmpty() Then
		
		TasksTable = QueryResult.Unload();
		For Each Row In TasksTable Do
			
			BusinessProcessesAndTasksServerCall.ExecuteTask(Row.Ref, True);
			
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Task ""%1"" was completed.'; ru = 'Задача ""%1"" завершена.';pl = 'Zadanie ""%1"" zostało zakończone.';es_ES = 'La tarea ""%1"" se ha finalizado.';es_CO = 'La tarea ""%1"" se ha finalizado.';tr = '""%1"" görevi tamamlandı.';it = 'Compito ""%1"" è stato completato.';de = 'Aufgabe ""%1"" war abgeschlossen.'"),
				Row.Ref);
			CommonClientServer.MessageToUser(MessageText);
			
		EndDo
		
	EndIf;
	
EndProcedure

Function GetPhasesPresentations(PhaseArray) Export
	
	PhasesPresentations = New Map;
	
	For Each PhaseItem In PhaseArray Do
		If PhasesPresentations.Get(PhaseItem) = Undefined Then
			Attributes = Common.ObjectAttributesValues(PhaseItem, "CodeWBS, Description");
			PhasesPresentations.Insert(PhaseItem, Attributes.CodeWBS + "  " + Attributes.Description);
		EndIf;
	EndDo;
	
	Return PhasesPresentations;
	
EndFunction

#Region Template

Function LoadProjectFromTemplate(ProjectTemplate, Project, CalculationStartDate) Export
	
	Cancel = False;
	
	If Not ValueIsFilled(ProjectTemplate) And Not ValueIsFilled(Project) Then
		Cancel = True;
		Return Cancel;
	EndIf;
	
	TemplateAttributes = Common.ObjectAttributesValues(ProjectTemplate, "WorkSchedule, DurationUnit, CalculationStartDate");
	
	If Not ValueIsFilled(CalculationStartDate) Then
		
		CalculationStartDate = CurrentSessionDate();
		
	EndIf;
	
	If Not ValueIsFilled(TemplateAttributes.CalculationStartDate) Then
		
		TemplateAttributes.CalculationStartDate = CalculationStartDate;
		
	EndIf;
	
	Delta = CalculationStartDate - TemplateAttributes.CalculationStartDate;
	
	DeleteProjectPhases(Project);
	
	BeginTransaction();
	
	Try
		
		ProjectObject = Project.GetObject();
		
		ProjectObject.WorkSchedule = TemplateAttributes.WorkSchedule;
		ProjectObject.UseWorkSchedule = ValueIsFilled(ProjectObject.WorkSchedule);
		ProjectObject.DurationUnit = TemplateAttributes.DurationUnit;
		ProjectObject.Write();
		
		Query = New Query;
		Query.Text = 
		"SELECT ALLOWED
		|	ProjectTemplatesPhasesTemplates.Code AS Code,
		|	ProjectTemplatesPhasesTemplates.Description AS Description,
		|	ProjectTemplatesPhasesTemplates.Parent AS Parent,
		|	ProjectTemplatesPhasesTemplates.Previous AS Previous,
		|	ProjectTemplatesPhasesTemplates.StartDate AS StartDate,
		|	ProjectTemplatesPhasesTemplates.Duration AS Duration,
		|	ProjectTemplatesPhasesTemplates.EndDate AS EndDate,
		|	ProjectTemplatesPhasesTemplates.IsProduction AS IsProduction
		|FROM
		|	Catalog.ProjectTemplates.PhasesTemplates AS ProjectTemplatesPhasesTemplates
		|WHERE
		|	ProjectTemplatesPhasesTemplates.Ref = &Ref
		|
		|ORDER BY
		|	ProjectTemplatesPhasesTemplates.LineNumber";
		
		Query.SetParameter("Ref", ProjectTemplate);
		
		ResultTable = Query.Execute().Unload();
		ResultTable.Columns.Add("Ref", New TypeDescription("CatalogRef.ProjectPhases"));
		ResultTable.Columns.Add("SummaryPhase", New TypeDescription("Boolean"));
		
		For Each Row In ResultTable Do
			
			PhaseObject = Catalogs.ProjectPhases.CreateItem();
			PhaseObject.Owner = ProjectObject.Ref;
			PhaseObject.Description = Row.Description;
			PhaseObject.Status = Enums.ProjectPhaseStatuses.Open;
			PhaseObject.IsProduction = Row.IsProduction;
			PhaseObject.CodeWBS = Row.Code;
			
			CodeParts = StringFunctionsClientServer.SplitStringIntoSubstringsArray(PhaseObject.CodeWBS, ".");
			If CodeParts.Count() > 0 Then
				PhaseObject.PhaseNumberInLevel = CodeParts[CodeParts.Count() - 1];
			EndIf;
			
			PhaseObject.DataExchange.Load = True;
			PhaseObject.Write();
			
			StartDate = Row.StartDate + Delta;
			If ValueIsFilled(StartDate) And ProjectObject.UseWorkSchedule Then
				StartDate = WorkSchedulesDrive.GetFirstWorkingTimeOfDay(ProjectObject.WorkSchedule, StartDate);
			EndIf;
			
			EndDate = Date(1, 1, 1);
			
			If ValueIsFilled(StartDate) And ValueIsFilled(Row.Duration) Then
				EndDate = CalculatePeriodEnd(PhaseObject.Ref,
					StartDate,
					Row.Duration,
					ProjectObject.DurationUnit);
			EndIf;
			
			DataStructure = New Structure;
			DataStructure.Insert("StartDate", StartDate);
			DataStructure.Insert("EndDate", EndDate);
			DataStructure.Insert("DurationUnit", ProjectObject.DurationUnit);
			DataStructure.Insert("Duration", Row.Duration);
			
			WriteProjectPhaseTimelines(PhaseObject.Ref, DataStructure);
			
			Row.Ref = PhaseObject.Ref;
			
		EndDo;
		
		For n = 0 To ResultTable.Count() - 1 Do
			
			PhaseRow = ResultTable[n];
			PhaseObject = PhaseRow.Ref.GetObject();
			
			If ValueIsFilled(PhaseRow.Parent) Then
				
				ParentRow = ResultTable.Find(PhaseRow.Parent, "Code");
				If ValueIsFilled(ParentRow) And ValueIsFilled(ParentRow.Ref) Then
					
					PhaseObject.Parent = ParentRow.Ref;
					
					If Not ParentRow.SummaryPhase Then
						
						ParentObject = ParentRow.Ref.GetObject();
						ParentObject.SummaryPhase = True;
						ParentObject.Write();
						
						ParentRow.SummaryPhase = True;
						
					EndIf;
					
				EndIf;
				
			EndIf;
			
			If ValueIsFilled(PhaseRow.Previous) Then
				PreviousRow = ResultTable.Find(PhaseRow.Previous, "Code");
				If ValueIsFilled(PreviousRow) And ValueIsFilled(PreviousRow.Ref) Then
					PhaseObject.PreviousPhase = PreviousRow.Ref;
				EndIf;
			EndIf;
			
			PhaseObject.DataExchange.Load = True;
			PhaseObject.Write();
			
		EndDo;
		
		ProjectManagement.CalculatePlanOfEntireProject(ProjectObject.Ref);
		
		CommitTransaction();
		
	Except
		
		RollbackTransaction();
		
		ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'For project ""%1"", couldn''t import data from the template. Details: %2.'; ru = 'Не удалось загрузить данные из шаблона для проекта ""%1"". Подробнее: %2.';pl = 'Dla projektu ""%1"", nie udało się importować danych z szablonu. Szczegóły: %2.';es_ES = 'Para el proyecto ""%1"", no se han podido importar los datos de la plantilla. Detalles: %2.';es_CO = 'Para el proyecto ""%1"", no se han podido importar los datos de la plantilla. Detalles: %2.';tr = '""%1"" projesi için veriler şablondan aktarılamadı. Ayrıntılar: %2.';it = 'Impossibile importare dati dal modello per il progetto ""%1"". Dettagli: %2.';de = 'Für Projekt ""%1"", könnten die Daten aus der Vorlage nicht importiert werden. Details: %2.'"),
			ProjectObject.Ref,
			BriefErrorDescription(ErrorInfo()));
		
		CommonClientServer.MessageToUser(ErrorDescription, , , , Cancel);
		
	EndTry;
	
	Return Not Cancel;
	
EndFunction

Function IsProjectPhasesExist(ProjectRef) Export
	
	Exist = False;
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	TRUE AS VrtField
	|FROM
	|	Catalog.ProjectPhases AS ProjectPhases
	|WHERE
	|	ProjectPhases.Owner = &Owner
	|	AND NOT ProjectPhases.DeletionMark";
	
	Query.SetParameter("Owner", ProjectRef);
	
	Result = Query.Execute();
	If Not Result.IsEmpty() Then
		Exist = True;
	EndIf;
	
	Return Exist;
	
EndFunction

#EndRegion

#Region PhaseStatus

Procedure UpdateParentsStatus(ProjectPhase, ModifiedPhasesArray = Undefined) Export
	
	ProjectPhaseOwner = Common.ObjectAttributeValue(ProjectPhase, "Owner");
	
	ProjectData = GetProjectData(ProjectPhaseOwner);
	
	If ModifiedPhasesArray = Undefined Then
		ModifiedPhasesArray = New Array;
	EndIf;
	
	UpdateParentsStatusByPhase(ProjectPhase, ModifiedPhasesArray, ProjectData);
	
	For Each Row In ProjectData Do
		
		If Row.Value.Modified Then
			
			ProjectPhaseObject = Row.Key.GetObject();
			ProjectPhaseObject.Status = Row.Value.Status;
			ProjectPhaseObject.Write();
			
		EndIf;
		
	EndDo;
	
EndProcedure

#EndRegion

#EndRegion

#Region Private

Function RecalculateDuration(Val Duration, UnitFrom, UnitTo, UseWorkSchedule, WorkSchedule = Undefined)
	
	PeriodSettings = Undefined;
	
	If UseWorkSchedule And ValueIsFilled(WorkSchedule) Then
		
		PeriodSettings = InformationRegisters.WorkSchedulePeriodSettings.GetWorkSchedulePeriodSettings(WorkSchedule);
		
	EndIf;
	
	If PeriodSettings <> Undefined Then
		WorkingHoursInDay = PeriodSettings.WorkingHoursInDay;
		WorkingHoursInWeek = PeriodSettings.WorkingHoursInWeek;
		WorkingDaysInMonth = PeriodSettings.WorkingDaysInMonth;
	Else
		WorkingHoursInDay = 24;
		WorkingHoursInWeek = 168;
		WorkingDaysInMonth = 30;
	EndIf;
	
	DurationSec = 0;
	
	If UnitFrom = Enums.DurationUnits.Minute Then
		DurationSec = Duration * 60;
	ElsIf UnitFrom = Enums.DurationUnits.Hour Then
		DurationSec = Duration * 3600;
	ElsIf UnitFrom = Enums.DurationUnits.Day Then
		DurationSec = Duration * (3600 * WorkingHoursInDay);
	ElsIf UnitFrom = Enums.DurationUnits.Week Then
		DurationSec = Duration * (3600 * WorkingHoursInWeek);
	ElsIf UnitFrom = Enums.DurationUnits.Month Then
		DurationSec = Duration * (3600 * WorkingHoursInDay * WorkingDaysInMonth);
	EndIf;
	
	If UnitTo = Enums.DurationUnits.Minute Then
		Duration = DurationSec / 60;
	ElsIf UnitTo = Enums.DurationUnits.Hour Then
		Duration = DurationSec / 3600;
	ElsIf UnitTo = Enums.DurationUnits.Day Then
		Duration = DurationSec / (3600 * WorkingHoursInDay);
	ElsIf UnitTo = Enums.DurationUnits.Week Then
		Duration = DurationSec / (3600 * WorkingHoursInWeek);
	ElsIf UnitTo = Enums.DurationUnits.Month Then
		Duration = DurationSec / (3600 * WorkingHoursInDay * WorkingDaysInMonth);
	EndIf;
	
	Return Duration;
	
EndFunction

Procedure CalculateProjectPlanByPhase(ProjectPhase,
	Val RecalculatePlanByPhase = False,
	ModifiedPhasesArray = Undefined,
	ProjectData = Undefined)
	
	If ProjectData = Undefined Then
		
		ProjectPhaseOwner = Common.ObjectAttributeValue(ProjectPhase, "Owner");
		
		ProjectData = GetProjectData(ProjectPhaseOwner);
		
		If TypeOf(ProjectPhase) = Type("CatalogRef.ProjectPhases") Then
			ProjectPhaseData = ProjectData.Get(ProjectPhase);
		Else
			ProjectPhaseData = ProjectPhase;
		EndIf;
		
	Else
		
		If TypeOf(ProjectPhase) = Type("CatalogRef.ProjectPhases") Then
			ProjectPhaseData = ProjectData.Get(ProjectPhase);
		Else
			ProjectPhaseData = ProjectPhase;
		EndIf;
		
	EndIf;
	
	If ProjectPhaseData = Undefined Then
		Return
	EndIf;
	
	If RecalculatePlanByPhase Then
		If ModifiedPhasesArray <> Undefined Then
			ModifiedPhasesArray.Add(ProjectPhaseData.Ref);
		EndIf;
	EndIf;
	
	If ProjectPhaseData.SummaryPhase Then
		
		SubordinatesPhases = ProjectPhaseData.SubordinatesPhases;
		
		If RecalculatePlanByPhase Then
			For Each SubordinatePhase In SubordinatesPhases Do
				CalculateProjectPlanByPhase(SubordinatePhase,, ModifiedPhasesArray, ProjectData);
			EndDo;
		EndIf;
		
		// actual dates
		StartDate = '99990101';
		EndDate = '00010101';
		
		For Each SubordinatePhase In SubordinatesPhases Do
			SubordinatePhaseData = ProjectData.Get(SubordinatePhase);
			If ValueIsFilled(SubordinatePhaseData.ActualStartDate)
				And SubordinatePhaseData.ActualStartDate < StartDate Then
				StartDate = SubordinatePhaseData.ActualStartDate;
			EndIf;
		EndDo;
		
		If StartDate = '99990101' Then
			StartDate = '00010101'
		EndIf;
		
		For Each SubordinatePhase In SubordinatesPhases Do
			SubordinatePhaseData = ProjectData.Get(SubordinatePhase);
			If Not ValueIsFilled(SubordinatePhaseData.ActualEndDate) Then
				EndDate = '00010101';
				Break;
			ElsIf SubordinatePhaseData.ActualEndDate > EndDate Then
				EndDate = SubordinatePhaseData.ActualEndDate;
			EndIf;
		EndDo;
		
		If (StartDate <> ProjectPhaseData.ActualStartDate Or EndDate <> ProjectPhaseData.ActualEndDate) Then
			
			ProjectPhaseData.ActualStartDate = StartDate;
			ProjectPhaseData.ActualEndDate = EndDate;
			ProjectPhaseData.ActualDuration = CalculatePeriodDuration(ProjectPhaseData,
				StartDate,
				EndDate,
				ProjectPhaseData.ActualDurationUnit);
			
			ProjectPhaseData.Modified = True;
			
			If ModifiedPhasesArray <> Undefined Then 
				ModifiedPhasesArray.Add(ProjectPhaseData.Ref);
			EndIf;
			
		EndIf;
		
		// plan dates
		StartDate = '99990101';
		EndDate = '00010101';
		
		For Each SubordinatePhase In SubordinatesPhases Do
			SubordinatePhaseData = ProjectData.Get(SubordinatePhase);
			If SubordinatePhaseData.StartDate < StartDate Then
				StartDate = SubordinatePhaseData.StartDate;
			EndIf;
			
			If SubordinatePhaseData.EndDate > EndDate Then
				EndDate = SubordinatePhaseData.EndDate;
			EndIf;
		EndDo;
		
		If StartDate = '99990101' Then
			StartDate = '00010101'
		EndIf;
		
		If (StartDate <> ProjectPhaseData.StartDate Or EndDate <> ProjectPhaseData.EndDate) Then
			
			ProjectPhaseData.StartDate = StartDate;
			ProjectPhaseData.EndDate = EndDate;
			ProjectPhaseData.Duration = CalculatePeriodDuration(ProjectPhaseData,
				StartDate,
				EndDate,
				ProjectPhaseData.DurationUnit);
			
			ProjectPhaseData.Modified = True;
			
			If ModifiedPhasesArray <> Undefined Then
				ModifiedPhasesArray.Add(ProjectPhaseData.Ref);
			EndIf;
			
			RecalculatePlanByPhase = True;
			
		EndIf;
		
		If RecalculatePlanByPhase Then
			
			If ValueIsFilled(ProjectPhaseData.Parent) Then
				CalculateProjectPlanByPhase(ProjectPhaseData.Parent,, ModifiedPhasesArray, ProjectData);
			EndIf;
			
		EndIf;
		
	Else
		
		ProcessProjectPhase(ProjectPhaseData, RecalculatePlanByPhase, ModifiedPhasesArray, ProjectData);
		
	EndIf;
	
EndProcedure

Function CreateProjectPhaseStructure()
	
	ProjectPhaseData = New Structure("Modified,
		|Ref, Parent, Owner, SummaryPhase, Status,
		|Project, ProjectStart, ProjectEnd, WorkSchedule, UseWorkSchedule,
		|CalculateDeadlinesAutomatically, StartDate, EndDate, Duration, DurationUnit,
		|ActualStartDate, ActualEndDate, ActualDuration, ActualDurationUnit,
		|AllParentPhases, SubordinatesPhases, AllSubordinatesPhases,
		|AllPrevious, AllNext");
	
	ProjectPhaseData.Modified = False;
	ProjectPhaseData.SubordinatesPhases = New Array;
	ProjectPhaseData.AllSubordinatesPhases = New Array;
	ProjectPhaseData.AllParentPhases = New Array;
	ProjectPhaseData.AllPrevious = New Array;
	ProjectPhaseData.AllNext = New Array;
	
	Return ProjectPhaseData;
	
EndFunction

Function GetProjectData(Project)
	
	SetPrivilegedMode(True);
	
	DataMap = New Map;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	ProjectPhases.Ref AS Ref,
	|	ProjectPhases.DeletionMark AS DeletionMark,
	|	ProjectPhases.Owner AS Project,
	|	ProjectPhases.Status AS Status,
	|	Projects.StartDate AS ProjectStart,
	|	Projects.EndDate AS ProjectEnd,
	|	Projects.UseWorkSchedule AS UseWorkSchedule,
	|	Projects.CalculateDeadlinesAutomatically AS CalculateDeadlinesAutomatically,
	|	Projects.WorkSchedule AS WorkSchedule,
	|	ProjectPhases.Parent AS Parent,
	|	ProjectPhases.SummaryPhase AS SummaryPhase,
	|	ProjectPhases.Owner AS Owner,
	|	ProjectPhasesTimelines.StartDate AS StartDate,
	|	ProjectPhasesTimelines.EndDate AS EndDate,
	|	ProjectPhasesTimelines.Duration AS Duration,
	|	ProjectPhasesTimelines.DurationUnit AS DurationUnit,
	|	ProjectPhasesTimelines.ActualStartDate AS ActualStartDate,
	|	ProjectPhasesTimelines.ActualEndDate AS ActualEndDate,
	|	ProjectPhasesTimelines.ActualDuration AS ActualDuration,
	|	ProjectPhasesTimelines.ActualDurationUnit AS ActualDurationUnit
	|FROM
	|	Catalog.Projects AS Projects
	|		INNER JOIN Catalog.ProjectPhases AS ProjectPhases
	|		ON Projects.Ref = ProjectPhases.Owner
	|		LEFT JOIN InformationRegister.ProjectPhasesTimelines AS ProjectPhasesTimelines
	|		ON (ProjectPhases.Ref = ProjectPhasesTimelines.ProjectPhase)
	|WHERE
	|	ProjectPhases.Owner = &Project
	|	AND NOT ProjectPhases.DeletionMark
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ProjectPhases.Ref AS Ref,
	|	ProjectPhases.Parent AS Parent
	|FROM
	|	Catalog.ProjectPhases AS ProjectPhases
	|WHERE
	|	ProjectPhases.Owner = &Project
	|	AND NOT ProjectPhases.DeletionMark
	|	AND ProjectPhases.Parent <> VALUE(Catalog.ProjectPhases.EmptyRef)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	ProjectPhases.Ref AS Ref,
	|	ProjectPhases.PreviousPhase AS PreviousPhase
	|FROM
	|	Catalog.ProjectPhases AS ProjectPhases
	|		INNER JOIN Catalog.ProjectPhases AS PreviousProjectPhases
	|		ON ProjectPhases.PreviousPhase = PreviousProjectPhases.Ref
	|WHERE
	|	ProjectPhases.Owner = &Project
	|	AND NOT ProjectPhases.DeletionMark
	|	AND NOT PreviousProjectPhases.DeletionMark";
	
	Query.SetParameter("Project", Project);
	
	Results = Query.ExecuteBatch();
	
	Result0 = Results[0].Unload();
	For Each Row In Result0 Do
		
		ProjectPhaseData = CreateProjectPhaseStructure();
		FillPropertyValues(ProjectPhaseData, Row);
		
		DataMap.Insert(ProjectPhaseData.Ref, ProjectPhaseData);
		
	EndDo;
	
	Result1 = Results[1].Unload();
	For Each Row In Result1 Do
		
		PhaseData = DataMap.Get(Row.Ref);
		
		ParentData = DataMap.Get(Row.Parent);
		ParentData.SubordinatesPhases.Add(Row.Ref);
		
		CurrentParent = Row.Parent;
		While ValueIsFilled(CurrentParent) Do
			ParentData = DataMap.Get(CurrentParent);
			ParentData.AllSubordinatesPhases.Add(Row.Ref);
			CurrentParent = ParentData.Parent;
		EndDo;
		
		CurrentParent = Row.Parent;
		While ValueIsFilled(CurrentParent) Do
			PhaseData.AllParentPhases.Add(CurrentParent);
			ParentData = DataMap.Get(CurrentParent);
			CurrentParent = ParentData.Parent;
		EndDo;
		
	EndDo;
	
	Result2 = Results[2].Unload();
	
	For Each Row In Result0 Do
		
		PhaseData = DataMap.Get(Row.Ref);
		
		PhasesList = New Array;
		PhasesList.Add(Row.Ref);
		
		For Each ParentPhase In PhaseData.AllParentPhases Do
			PhasesList.Add(ParentPhase);
		EndDo;
		
		For Each Phase In PhasesList Do
			
			FoundRows = Result2.FindRows(New Structure("Ref", Phase));
			For Each FoundRow In FoundRows Do
				
				PreviousPhaseData = DataMap.Get(FoundRow.PreviousPhase);
				If PreviousPhaseData.SummaryPhase Then
					
					For Each SubordinatePhase In PreviousPhaseData.AllSubordinatesPhases Do
						
						SubordinatePhaseData = DataMap.Get(SubordinatePhase);
						If SubordinatePhaseData.SummaryPhase Then
							Continue;
						EndIf;
						
						Data = New Structure;
						Data.Insert("Ref", Phase);
						Data.Insert("PreviousPhase", SubordinatePhase);
						
						PhaseData.AllPrevious.Add(Data);
						
					EndDo;
					
				Else
					
					Data = New Structure;
					Data.Insert("Ref", Phase);
					Data.Insert("PreviousPhase", FoundRow.PreviousPhase);
					
					PhaseData.AllPrevious.Add(Data);
					
				EndIf;
				
			EndDo;
			
		EndDo;
		
	EndDo;
	
	For Each Row In Result0 Do
		
		PhaseData = DataMap.Get(Row.Ref);
		
		PhasesList = New Array;
		PhasesList.Add(Row.Ref);
		
		For Each ParentPhase In PhaseData.AllParentPhases Do
			PhasesList.Add(ParentPhase);
		EndDo;
		
		For Each Phase In PhasesList Do
			
			FoundRows = Result2.FindRows(New Structure("PreviousPhase", Phase));
			For Each FoundRow In FoundRows Do
				
				NextData = DataMap.Get(FoundRow.Ref);
				If NextData.SummaryPhase Then
					
					For Each SubordinatePhase In NextData.AllSubordinatesPhases Do
						
						SubordinatePhaseData = DataMap.Get(SubordinatePhase);
						If SubordinatePhaseData.SummaryPhase Then
							Continue;
						EndIf;
						
						PhaseData.AllNext.Add(New Structure("Ref", SubordinatePhase));
						
					EndDo;
					
				Else
					
					PhaseData.AllNext.Add(New Structure("Ref", FoundRow.Ref));
					
				EndIf;
				
			EndDo;
			
		EndDo;
		
	EndDo;
	
	Return DataMap;
	
EndFunction

Procedure ProcessProjectPhase(ProjectPhaseData, RecalculatePlanByPhase, ModifiedPhasesArray, ProjectData)
	
	StartDate = ProjectPhaseData.StartDate;
	
	AllPrevious = ProjectPhaseData.AllPrevious;
	
	For Each Row In AllPrevious Do
		
		NewStartDate = ProjectData.Get(Row.PreviousPhase).EndDate;
		
		If ProjectPhaseData.UseWorkSchedule And ProjectPhaseData.Duration <> 0 Then
			
			WorkSchedule = GetProjectWorkSchedule(ProjectPhaseData.Owner);
			TmpNewStartDate = WorkSchedulesDrive.GetPeriodEndDateSec(WorkSchedule, NewStartDate, 1);
			
			If TmpNewStartDate - 1 <> NewStartDate Then
				NewStartDate = TmpNewStartDate - 1;
			EndIf;
			
		EndIf;
		
		If ValueIsFilled(NewStartDate) Then
			If NewStartDate > StartDate Then
				StartDate = NewStartDate;
			EndIf;
		EndIf;
		
	EndDo;
	
	If StartDate <> ProjectPhaseData.StartDate Then
		
		If ProjectPhaseData.CalculateDeadlinesAutomatically Then
			
			ProjectPhaseData.StartDate = StartDate;
			ProjectPhaseData.EndDate = CalculatePeriodEnd(ProjectPhaseData,
				StartDate,
				ProjectPhaseData.Duration,
				ProjectPhaseData.DurationUnit);
			
			ProjectPhaseData.Modified = True;
			
			If ModifiedPhasesArray <> Undefined Then
				ModifiedPhasesArray.Add(ProjectPhaseData.Ref);
			EndIf;
			
		EndIf;
		
		RecalculatePlanByPhase = True;
		
	EndIf;
	
	If RecalculatePlanByPhase Then
		
		If ValueIsFilled(ProjectPhaseData.Parent) Then
			CalculateProjectPlanByPhase(ProjectPhaseData.Parent, , ModifiedPhasesArray, ProjectData);
		EndIf;
		
		For Each Row In ProjectPhaseData.AllNext Do
			CalculateProjectPlanByPhase(Row.Ref, , ModifiedPhasesArray, ProjectData);
		EndDo;
		
	EndIf;
	
EndProcedure

Function GetAllSubordinatesPhases(ProjectPhase)
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	ProjectPhases.Ref AS Ref,
	|	ProjectPhases.SummaryPhase AS SummaryPhase,
	|	ProjectPhasesTimelines.StartDate AS StartDate,
	|	ProjectPhasesTimelines.EndDate AS EndDate,
	|	ProjectPhasesTimelines.Duration AS Duration,
	|	ProjectPhasesTimelines.DurationUnit AS DurationUnit,
	|	ProjectPhasesTimelines.ActualStartDate AS ActualStartDate,
	|	ProjectPhasesTimelines.ActualEndDate AS ActualEndDate,
	|	ProjectPhasesTimelines.ActualDuration AS ActualDuration,
	|	ProjectPhasesTimelines.ActualDurationUnit AS ActualDurationUnit
	|FROM
	|	Catalog.ProjectPhases AS ProjectPhases
	|		LEFT JOIN InformationRegister.ProjectPhasesTimelines AS ProjectPhasesTimelines
	|		ON ProjectPhases.Ref = ProjectPhasesTimelines.ProjectPhase
	|WHERE
	|	ProjectPhases.Ref IN HIERARCHY(&ProjectPhase)
	|	AND NOT ProjectPhases.DeletionMark";
	
	Query.SetParameter("ProjectPhase", ProjectPhase);
	Result = Query.Execute();
	
	Return Result.Unload();
	
EndFunction

Procedure CheckPredecessorsForLooping(ProjectPhase, PhasesInProcessing, PhasesProcessed)
	
	If PhasesProcessed.Find(ProjectPhase) <> Undefined Then
		Return;
	EndIf;
	
	If PhasesInProcessing.Find(ProjectPhase) <> Undefined Then 
		
		Raise NStr("en = 'Cannot save this phase. Previous phase is set to a phase
					|whose previous phase is this phase. Select another previous phase.'; 
					|ru = 'Не удалось сохранить этап. Предыдущим этапом назначен этап,
					|предыдущим этапом которого является данный этап. Выберите другой предыдущий этап.';
					|pl = 'Nie można zapisać tego etapu. Poprzedni etap jest ustawiony na etap,
					|poprzednim etapem którego jest ten etap. Wybierz inny poprzedni etap.';
					|es_ES = 'No se ha podido guardar esta fase. La fase anterior está establecida en una fase
					|cuya fase anterior es esta fase. Seleccione otra fase anterior.';
					|es_CO = 'No se ha podido guardar esta fase. La fase anterior está establecida en una fase
					|cuya fase anterior es esta fase. Seleccione otra fase anterior.';
					|tr = 'Bu evre kaydedilemiyor. Önceki evre, önceki evresi
					|bu evre olan bir evreye ayarlı. Başka bir önceki evre seçin.';
					|it = 'Impossibile salvare questa fase. La fase precedente è impostata su una fase
					|la cui fase precedente è questa fase. Seleziona un''altra fase precedente.';
					|de = 'Fehler beim Speichern dieser Phase. Die vorherige Phase ist zu einer Phase
					| deren vorherige Phase diese Phase ist, gesetzt. Wählen Sie eine andere vorherige Phase aus.'");
		
	EndIf;
	
	PhasesInProcessing.Add(ProjectPhase);
	
	PreviousPhases = GetAllPreviousPhasesIncludingSubordinates(ProjectPhase);
	For Each Row In PreviousPhases Do
		CheckPredecessorsForLooping(Row.PreviousPhase, PhasesInProcessing, PhasesProcessed);
	EndDo;
	
	PhasesProcessed.Add(ProjectPhase);
	
	PhasesInProcessing.Delete(PhasesInProcessing.Find(ProjectPhase));
	
EndProcedure

Procedure FillInSubordinatePhasesOrder(Parent, ProjectPhaseNumber)
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	ProjectPhases.Ref AS Ref
	|FROM
	|	Catalog.ProjectPhases AS ProjectPhases
	|WHERE
	|	ProjectPhases.Parent = &Parent
	|
	|ORDER BY
	|	ProjectPhases.PhaseNumberInLevel,
	|	ProjectPhases.Description";
	
	Query.SetParameter("Parent", Parent);
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		
		InformationRegisters.ProjectPhasesOrder.SetProjectPhaseOrder(Selection.Ref, ProjectPhaseNumber);
		
		ProjectPhaseNumber = ProjectPhaseNumber + 1;
		
		FillInSubordinatePhasesOrder(Selection.Ref, ProjectPhaseNumber)
		
	EndDo;
	
EndProcedure

Procedure DeleteProjectPhases(ProjectRef)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	ProjectPhases.Ref AS Ref
	|FROM
	|	Catalog.ProjectPhases AS ProjectPhases
	|WHERE
	|	ProjectPhases.Owner = &Owner
	|	AND NOT ProjectPhases.DeletionMark";
	
	Query.SetParameter("Owner", ProjectRef);
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		ProjectPhase = Selection.Ref.GetObject();
		ProjectPhase.SetDeletionMark(True, False);
	EndDo;
	
EndProcedure

Procedure UpdateParentsStatusByPhase(ProjectPhase, ModifiedPhasesArray = Undefined, ProjectData = Undefined)
	
	If ProjectData = Undefined Then
		
		ProjectPhaseOwner = Common.ObjectAttributeValue(ProjectPhase, "Owner");
		
		ProjectData = GetProjectData(ProjectPhaseOwner);
		
		If TypeOf(ProjectPhase) = Type("CatalogRef.ProjectPhases") Then
			ProjectPhaseData = ProjectData.Get(ProjectPhase);
		Else
			ProjectPhaseData = ProjectPhase;
		EndIf;
		
	Else
		
		If TypeOf(ProjectPhase) = Type("CatalogRef.ProjectPhases") Then
			ProjectPhaseData = ProjectData.Get(ProjectPhase);
		Else
			ProjectPhaseData = ProjectPhase;
		EndIf;
		
	EndIf;
	
	If ProjectPhaseData = Undefined Then
		Return;
	EndIf;
	
	If ProjectPhaseData.SummaryPhase Then
		
		SubordinatesPhases = ProjectPhaseData.SubordinatesPhases;
		
		AllOpen = True;
		AllCompleted = True;
		
		For Each SubordinatePhase In SubordinatesPhases Do
			
			SubordinatePhaseData = ProjectData.Get(SubordinatePhase);
			
			If AllOpen And SubordinatePhaseData.Status <> Enums.ProjectPhaseStatuses.Open Then
				AllOpen = False;
			EndIf;
			
			If AllCompleted And SubordinatePhaseData.Status <> Enums.ProjectPhaseStatuses.Completed Then
				AllCompleted = False;
			EndIf;
			
		EndDo;
		
		If AllOpen Then
			Status = Enums.ProjectPhaseStatuses.Open;
		ElsIf AllCompleted Then
			Status = Enums.ProjectPhaseStatuses.Completed;
		Else
			Status = Enums.ProjectPhaseStatuses.InProgress;
		EndIf;
		
		If Status <> ProjectPhaseData.Status Then
			
			ProjectPhaseData.Status = Status;
			ProjectPhaseData.Modified = True;
			
			If ModifiedPhasesArray <> Undefined Then
				ModifiedPhasesArray.Add(ProjectPhaseData.Ref);
			EndIf;
			
		EndIf;
		
	EndIf;
	
	If ValueIsFilled(ProjectPhaseData.Parent) Then
		UpdateParentsStatusByPhase(ProjectPhaseData.Parent, ModifiedPhasesArray, ProjectData);
	EndIf;
	
EndProcedure

Function GetProjectWorkSchedule(Project)
	
	WorkSchedule = Common.ObjectAttributeValue(Project, "WorkSchedule");
	If ValueIsFilled(WorkSchedule) Then 
		Return WorkSchedule;
	EndIf;
	
	Return Catalogs.WorkSchedules.EmptyRef();
	
EndFunction

Function GetAllPreviousPhasesIncludingSubordinates(ProjectPhase)
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	ProjectPhases.Ref AS Ref
	|FROM
	|	Catalog.ProjectPhases AS ProjectPhases
	|WHERE
	|	ProjectPhases.Ref IN HIERARCHY(&ProjectPhase)
	|	AND NOT ProjectPhases.DeletionMark
	|TOTALS BY
	|	Ref ONLY HIERARCHY";
	
	Query.SetParameter("ProjectPhase", ProjectPhase);
	
	PhasesArray = Query.Execute().Unload().UnloadColumn("Ref");
	
	Query = New Query;
	Query.Text =
	"SELECT DISTINCT
	|	ProjectPhases.Ref AS Ref,
	|	ProjectPhases.PreviousPhase AS PreviousPhase,
	|	ProjectPhasesTimelines.StartDate AS StartDate,
	|	ProjectPhasesTimelines.EndDate AS EndDate
	|FROM
	|	Catalog.ProjectPhases AS ProjectPhases
	|		INNER JOIN Catalog.ProjectPhases AS PreviousProjectPhases
	|		ON ProjectPhases.PreviousPhase = PreviousProjectPhases.Ref
	|		LEFT JOIN InformationRegister.ProjectPhasesTimelines AS ProjectPhasesTimelines
	|		ON ProjectPhases.PreviousPhase = ProjectPhasesTimelines.ProjectPhase
	|WHERE
	|	ProjectPhases.Ref IN(&PhasesArray)
	|	AND NOT PreviousProjectPhases.DeletionMark";
	
	Query.SetParameter("PhasesArray", PhasesArray);
	
	Result = Query.Execute().Unload();
	
	Return Result;
	
EndFunction

#EndRegion