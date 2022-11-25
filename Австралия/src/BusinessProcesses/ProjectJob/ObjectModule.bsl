#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

#Region ForCallsFromOtherSubsystems

// StandardSubsystems.AccessManagement

// See AccessManagement.FillAccessValuesSets.
//
// Parameters:
//   Table - ValueTable - see AccessManagement.AccessValuesSetsTable.
//
Procedure FillAccessValuesSets(Table) Export
	
	BusinessProcessesAndTasksOverridable.OnFillingAccessValuesSets(ThisObject, Table);
	
	If Table.Count() > 0 Then
		Return;
	EndIf;
	
	FillDefaultAccessValuesSets(Table);
	
EndProcedure

// End StandardSubsystems.AccessManagement

#EndRegion

#EndRegion

#Region EventHandlers

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Author <> Undefined And Not Author.IsEmpty() Then
		AuthorString = String(Author);
	EndIf;
	
	BusinessProcessesAndTasksServer.ValidateRightsToChangeBusinessProcessState(ThisObject);
	
	SetPrivilegedMode(True);
	TaskPerformersGroup = ?(TypeOf(Performer) = Type("CatalogRef.PerformerRoles"),
		BusinessProcessesAndTasksServer.TaskPerformersGroup(Performer, MainAddressingObject, AdditionalAddressingObject),
		Performer);
	SetPrivilegedMode(False);
	
	If Not IsNew() And Common.ObjectAttributeValue(Ref, "Topic") <> Topic Then
		ChangeTaskSubject();
	EndIf;
	
EndProcedure

Procedure Filling(FillingData, FillingText, StandardProcessing)
	
	If IsNew() Then
		Author = Users.AuthorizedUser();
	EndIf;
	
	If TypeOf(FillingData) = Type("CatalogRef.ProjectPhases") Then
		
		Query = New Query;
		Query.Text =
		"SELECT
		|	ProjectPhases.Ref AS ProjectPhase,
		|	ProjectPhases.Ref AS Topic,
		|	ProjectPhases.Owner AS Project,
		|	ProjectPhases.Description AS Description,
		|	ProjectPhases.Executor AS Executor,
		|	ProjectPhasesTimelines.EndDate AS DueDate
		|FROM
		|	Catalog.ProjectPhases AS ProjectPhases
		|		LEFT JOIN InformationRegister.ProjectPhasesTimelines AS ProjectPhasesTimelines
		|		ON ProjectPhases.Ref = ProjectPhasesTimelines.ProjectPhase
		|WHERE
		|	ProjectPhases.Ref = &Ref";
		
		Query.SetParameter("Ref", FillingData);
		Result = Query.Execute();
		
		If Not Result.IsEmpty() Then
			
			Selection = Result.Select();
			Selection.Next();
			
			If IsNew() Then
				Performer = Selection.Executor;
			EndIf;
			
			FillPropertyValues(ThisObject, Selection);
			
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure OnCopy(CopiedObject)
	
	JobCompleted = False;
	CompletedOn = '00010101000000';
	State = Enums.BusinessProcessStates.Running;
	
EndProcedure

Procedure ExecuteOnCreateTasks(BusinessProcessRoutePoint, TasksBeingFormed, Cancel)
	
	Write();
	
	// Setting the addressing attributes and additional attributes for each task.
	For Each Task In TasksBeingFormed Do
		
		Task.Author = Author;
		Task.AuthorString = String(Author);
		If TypeOf(Performer) = Type("CatalogRef.PerformerRoles") Then
			Task.PerformerRole = Performer;
			Task.MainAddressingObject = MainAddressingObject;
			Task.AdditionalAddressingObject = AdditionalAddressingObject;
			Task.Performer = Undefined;
		Else
			Task.Performer = Performer;
		EndIf;
		Task.Description = Description;
		Task.DueDate = DueDate;
		Task.Importance = Importance;
		Task.Topic = Topic;
		Task.Project = Project;
		Task.ProjectPhase = ProjectPhase;
		
	EndDo;
	
EndProcedure

Procedure ExecuteOnExecute(BusinessProcessRoutePoint, Task, Cancel)
	
	Write();
	
EndProcedure

Procedure CompletionOnComplete(BusinessProcessRoutePoint, Cancel)
	
	CompletedOn = BusinessProcessesAndTasksServer.BusinessProcessCompletionDate(Ref);
	Write();
	
EndProcedure

#EndRegion

#Region Private

Procedure ChangeUncompletedTasksAttributes() Export
	
	BeginTransaction();
	
	Try
		Lock = New DataLock;
		LockItem = Lock.Add("Task.PerformerTask");
		LockItem.SetValue("BusinessProcess", Ref);
		Lock.Lock();
		
		Query = New Query;
		Query.Text =
		"SELECT
		|	Tasks.Ref AS Ref
		|FROM
		|	Task.PerformerTask AS Tasks
		|WHERE
		|	Tasks.BusinessProcess = &BusinessProcess
		|	AND NOT Tasks.DeletionMark
		|	AND NOT Tasks.Executed";
		
		Query.SetParameter("BusinessProcess", Ref);
		DetailedRecordsSelection = Query.Execute().Select();
		
		While DetailedRecordsSelection.Next() Do
			TaskObject = DetailedRecordsSelection.Ref.GetObject();
			TaskObject.Importance = Importance;
			TaskObject.DueDate = DueDate;
			TaskObject.Description = Description;
			TaskObject.Author = Author;
			TaskObject.Write();
		EndDo;
		
		CommitTransaction();
		
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure 

Procedure ChangeTaskSubject()
	
	SetPrivilegedMode(True);
	
	BeginTransaction();
	
	Try
		Lock = New DataLock;
		LockItem = Lock.Add("Task.PerformerTask");
		LockItem.SetValue("BusinessProcess", Ref);
		Lock.Lock();
		
		Query = New Query;
		Query.Text =
		"SELECT
		|	Tasks.Ref AS Ref
		|FROM
		|	Task.PerformerTask AS Tasks
		|WHERE
		|	Tasks.BusinessProcess = &BusinessProcess";
		
		Query.SetParameter("BusinessProcess", Ref);
		DetailedRecordsSelection = Query.Execute().Select();
		
		While DetailedRecordsSelection.Next() Do
			TaskObject = DetailedRecordsSelection.Ref.GetObject();
			TaskObject.Topic = Topic;
			TaskObject.Write();
		EndDo;
		
		CommitTransaction();
		
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

Procedure FillDefaultAccessValuesSets(Table)
	
	// Default restriction logic for
	// - Reading:    Author OR Performer (taking into account addressing).
	// - Changes: Author.
	
	// If the subject is not specified (the business process is not based on another subject), then the subject is not involved in the restriction logic.
	
	// Read, Update: set #1.
	Row = Table.Add();
	Row.SetNumber     = 1;
	Row.Read          = True;
	Row.Update       = True;
	Row.AccessValue = Author;
	
	// Read: set No. 2.
	Row = Table.Add();
	Row.SetNumber     = 2;
	Row.Read          = True;
	Row.AccessValue = TaskPerformersGroup;
	
EndProcedure

#EndRegion

#EndIf