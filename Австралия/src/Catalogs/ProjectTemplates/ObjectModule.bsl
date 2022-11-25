#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure Filling(FillingData, FillingText, StandardProcessing)
	
	If TypeOf(FillingData) = Type("CatalogRef.Projects") Then
		
		Query = New Query;
		Query.Text = 
		"SELECT
		|	Projects.WorkSchedule AS WorkSchedule,
		|	Projects.DurationUnit AS DurationUnit
		|FROM
		|	Catalog.Projects AS Projects
		|WHERE
		|	Projects.Ref = &Ref
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	ProjectPhases.Description AS Description,
		|	ProjectPhases.IsProduction AS IsProduction,
		|	ProjectPhases.CodeWBS AS Code,
		|	ISNULL(PreviousPhases.CodeWBS, """") AS Previous,
		|	ISNULL(ParentPhases.CodeWBS, """") AS Parent,
		|	ISNULL(ProjectPhasesTimelines.StartDate, DATETIME(1, 1, 1)) AS StartDate,
		|	ISNULL(ProjectPhasesTimelines.Duration, 0) AS Duration,
		|	ISNULL(ProjectPhasesTimelines.EndDate, DATETIME(1, 1, 1)) AS EndDate
		|FROM
		|	Catalog.ProjectPhases AS ProjectPhases
		|		LEFT JOIN InformationRegister.ProjectPhasesTimelines AS ProjectPhasesTimelines
		|		ON (ProjectPhasesTimelines.ProjectPhase = ProjectPhases.Ref)
		|		LEFT JOIN Catalog.ProjectPhases AS ParentPhases
		|		ON ProjectPhases.Parent = ParentPhases.Ref
		|		LEFT JOIN Catalog.ProjectPhases AS PreviousPhases
		|		ON ProjectPhases.PreviousPhase = PreviousPhases.Ref
		|WHERE
		|	ProjectPhases.Owner = &Ref
		|	AND NOT ProjectPhases.DeletionMark
		|
		|ORDER BY
		|	ProjectPhases.PhaseNumberInLevel HIERARCHY";
		
		Query.SetParameter("Ref", FillingData);
		
		QueryResult = Query.ExecuteBatch();
		
		Header = QueryResult[0].Unload();
		If Header.Count() > 0 Then
			DurationUnit = Header[0].DurationUnit;
			WorkSchedule = Header[0].WorkSchedule;
		EndIf;
		
		TabSection = QueryResult[1].Unload();
		If TabSection.Count() > 0 Then
			
			PhasesTemplates.Load(TabSection);
			
			TabSection.Sort("StartDate");
			CalculationStartDate = TabSection[0].StartDate;
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#EndIf