#Region Internal

// Fills a user's to-do list.
//
// Parameters:
//  Parameters - Structure - blank structure.
//  ResultAddress - String - an address of a temporary storage where a user's to-do list is saved - 
//                                ValueTable:
//    * ID - String - an internal to-do ID used by the To-do list algorithm.
//    * HasUserTasks - Boolean - if True, a to-do is displayed in the user's to-do list.
//    * Important - Boolean - if True, a to-do is highlighted in red.
//    * Presentation - String - to-do presentation displayed to the user.
//    * Count - Number - a quantitative indicator of a to-do displayed in a to-do title.
//    * Form - String - a full path to the form that is displayed by clicking the to-do hyperlink in 
//                               the To-do list panel.
//    * FormParameters - Structure - parameters for opening the indicator form.
//    * Owner - String and metadata object - string ID of the to-do that is the owner of the current 
//                      to-do, or a subsystem metadata object.
//    * Tooltip - String - a tooltip text.
//
Procedure GenerateToDoListForUser(Parameters, ResultAddress) Export
	
	ToDoList = NewToDoListTable();
	
	UserTasksCount = 0;
	AddUserTask(ToDoList, SSLSubsystemsIntegration, UserTasksCount);
	
	// Adding to-dos of applied configurations.
	UserTasksFillingHandlers = New Array;
	ToDoListOverridable.OnDetermineToDoListHandlers(UserTasksFillingHandlers);
	
	For Each Handler In UserTasksFillingHandlers Do
		AddUserTask(ToDoList, Handler, UserTasksCount);
	EndDo;
	
	// Result post-processing.
	TransformToDoListTable(ToDoList);
	
	PutToTempStorage(ToDoList, ResultAddress);
	
EndProcedure

// Returns a structure of saved settings for displaying to-dos for the current user.
// 
//
Function SavedViewSettings() Export
	
	ViewSettings = CommonSettingsStorage.Load("ToDoList", "ViewSettings");
	If ViewSettings = Undefined Then
		Return Undefined;
	EndIf;
	
	If TypeOf(ViewSettings) <> Type("Structure") Then
		Return Undefined;
	EndIf;
	
	If ViewSettings.Property("UserTasksTree")
		AND ViewSettings.Property("SectionsVisibility")
		AND ViewSettings.Property("UserTasksVisible") Then
		Return ViewSettings;
	EndIf;
	
	Return Undefined;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Configuration subsystems event handlers.

// See UsersOverridable.OnDefineRolesAssignment. 
Procedure OnDefineRoleAssignment(RolesAssignment) Export
	
	// BothForUsersAndExternalUsers.
	RolesAssignment.BothForUsersAndExternalUsers.Add(
		Metadata.Roles.UseDataProcessorToDoList.Name);
	
EndProcedure

// See CommonOverridable.OnAddMetadataObjectsRenaming. 
Procedure OnAddMetadataObjectsRenaming(Total) Export
	
	Library = "StandardSubsystems";
	
	OldName = "Role.ToDoListUsage";
	NewName  = "Role.UseDataProcessorToDoList";
	Common.AddRenaming(Total, "2.3.3.25", OldName, NewName, Library);
	
	
EndProcedure

#EndRegion

#Region Private

// Gets numeric values of to-dos from a passed query.
//
// Query with data must have only one string with an arbitrary number of fields.
// Values of such fields must be values of matching indicators.
//
// Example of the simplest query:
//	SELECT
//		COUNT(*) AS <Name of a predefined item being a document quantity indicator>.
//	FROM
//		Document.<Document name>.
//
// Parameters:
//  Query - a running query.
//  CommonQueryParameters - Structure - common values for calculating current to-dos.
//
Function NumericUserTasksIndicators(Query, CommonQueryParameters = Undefined) Export
	
	// Set common parameters for all queries.
	// Specific parameters of this query, if any, must be set earlier.
	If Not CommonQueryParameters = Undefined Then
		SetCommonQueryParameters(Query, CommonQueryParameters);
	EndIf;
	
	Result = Query.ExecuteBatch();
	
	BatchQueriesNumbers = New Array;
	BatchQueriesNumbers.Add(Result.Count() - 1);
	
	// Select all queries with data.
	QueryResult = New Structure;
	For Each QueryNumber In BatchQueriesNumbers Do
		
		Selection = Result[QueryNumber].Select();
		
		If Selection.Next() Then
			
			For Each Column In Result[QueryNumber].Columns Do
				UserTaskValue = ?(TypeOf(Selection[Column.Name]) = Type("Null"), 0, Selection[Column.Name]);
				QueryResult.Insert(Column.Name, UserTaskValue);
			EndDo;
			
		EndIf;
		
	EndDo;
	
	Return QueryResult;
	
EndFunction

// Returns a structure of common values used for calculating current to-dos.
//
// Returns:
//  Structure - a value name and a value.
//
Function CommonQueryParameters() Export
	
	CommonQueryParameters = New Structure;
	CommonQueryParameters.Insert("User", UsersClientServer.CurrentUser());
	CommonQueryParameters.Insert("IsFullUser", Users.IsFullUser());
	CommonQueryParameters.Insert("CurrentDate", CurrentSessionDate());
	CommonQueryParameters.Insert("EmptyDate", '00010101000000');
	
	Return CommonQueryParameters;
	
EndFunction

// Sets common query parameters to calculate the current to-dos.
//
// Parameters:
//  Query - a running query.
//  CommonQueryParameters - Structure - common values for calculating indicators.
//
Procedure SetCommonQueryParameters(Query, CommonQueryParameters) Export
	
	For Each KeyAndValue In CommonQueryParameters Do
		Query.SetParameter(KeyAndValue.Key, KeyAndValue.Value);
	EndDo;
	
	ToDoListOverridable.SetCommonQueryParameters(Query, CommonQueryParameters);
	
EndProcedure

// For internal use only.
//
Procedure SetInitialSectionsOrder(ToDoList) Export
	
	CommandInterfaceSectionOrder = New Array;
	ToDoListOverridable.OnDetermineCommandInterfaceSectionsOrder(CommandInterfaceSectionOrder);
	
	Index = 0;
	For Each CommandInterfaceSection In CommandInterfaceSectionOrder Do
		If TypeOf(CommandInterfaceSection) = Type("String") Then
			CommandInterfaceSection = StrReplace(CommandInterfaceSection, " ", "");
		Else
			CommandInterfaceSection = StrReplace(CommandInterfaceSection.FullName(), ".", "");
		EndIf;
		RowsFilter = New Structure;
		RowsFilter.Insert("OwnerID", CommandInterfaceSection);
		
		FoundRows = ToDoList.FindRows(RowsFilter);
		For Each FoundRow In FoundRows Do
			RowIndexInTable = ToDoList.IndexOf(FoundRow);
			If RowIndexInTable = Index Then
				Index = Index + 1;
				Continue;
			EndIf;
			
			ToDoList.Move(RowIndexInTable, (Index - RowIndexInTable));
			Index = Index + 1;
		EndDo;
		
	EndDo;
	
EndProcedure

// For internal use only.
//
Procedure TransformToDoListTable(ToDoList)
	
	ToDoList.Columns.Add("OwnerID", New TypeDescription("String", New StringQualifiers(250)));
	ToDoList.Columns.Add("IsSection", New TypeDescription("Boolean"));
	ToDoList.Columns.Add("SectionPresentation", New TypeDescription("String", New StringQualifiers(250)));
	
	UserTasksToRemove = New Array;
	For Each UserTask In ToDoList Do
		
		If TypeOf(UserTask.Owner) = Type("MetadataObject") Then
			SectionAvailable = Common.MetadataObjectAvailableByFunctionalOptions(UserTask.Owner);
			If Not SectionAvailable Then
				UserTasksToRemove.Add(UserTask);
				Continue;
			EndIf;
			
			UserTask.OwnerID = StrReplace(UserTask.Owner.FullName(), ".", "");
			UserTask.IsSection              = True;
			UserTask.SectionPresentation   = ?(ValueIsFilled(UserTask.Owner.Synonym), UserTask.Owner.Synonym, UserTask.Owner.Name);
		Else
			If TypeOf(UserTask.Owner) = Type("DataProcessorManager.ToDoList") Then
				UserTask.Owner = UserTask.Owner.FullName();
				UserTask.ID = StrReplace(UserTask.ID, " ", "");
				UserTask.ID = StrReplace(UserTask.ID, "-", "");
			EndIf;
			
			IsUserTaskID = (ToDoList.Find(UserTask.Owner, "ID") <> Undefined);
			If Not IsUserTaskID Then
				OwnerToFind = StrReplace(UserTask.Owner, " ", "");
				OwnerToFind = StrReplace(OwnerToFind, "-", "");
				
				IsUserTaskID = (ToDoList.Find(OwnerToFind, "ID") <> Undefined);
			EndIf;
			
			InvalidCharacters = """'`/\-[]{}:;|=?*<>,.()+#№@!%^&~";
			UserTask.OwnerID = StrReplace(UserTask.Owner, " ", "");
			UserTask.OwnerID = StrConcat(StrSplit(UserTask.OwnerID, InvalidCharacters));
			If Not IsUserTaskID Then
				UserTask.IsSection              = True;
				UserTask.SectionPresentation   = UserTask.Owner;
			EndIf;
		EndIf;
		
	EndDo;
	
	For Each UserTaskToRemove In UserTasksToRemove Do
		ToDoList.Delete(UserTaskToRemove);
	EndDo;
	
	ToDoList.Columns.Delete("Owner");
	
EndProcedure

// Creates an empty table of a user's to-dos.
//
// Returns:
//  See ToDoListOverridable.OnDetermineToDoListHandlers. 
//
Function NewToDoListTable()
	
	UserTasks = New ValueTable;
	UserTasks.Columns.Add("ID", New TypeDescription("String", New StringQualifiers(250)));
	UserTasks.Columns.Add("HasUserTasks", New TypeDescription("Boolean"));
	UserTasks.Columns.Add("Important", New TypeDescription("Boolean"));
	UserTasks.Columns.Add("Presentation", New TypeDescription("String", New StringQualifiers(250)));
	UserTasks.Columns.Add("HideInSettings", New TypeDescription("Boolean"));
	UserTasks.Columns.Add("Count", New TypeDescription("Number"));
	UserTasks.Columns.Add("Form", New TypeDescription("String", New StringQualifiers(250)));
	UserTasks.Columns.Add("FormParameters", New TypeDescription("Structure"));
	UserTasks.Columns.Add("Owner");
	UserTasks.Columns.Add("ToolTip", New TypeDescription("String", New StringQualifiers(250)));
	
	Return UserTasks;
	
EndFunction

Procedure AddUserTask(ToDoList, Manager, UserTasksCount)
	
	If Common.SubsystemExists("StandardSubsystems.PerformanceMonitor") Then
		ModulePerformanceMonitor = Common.CommonModule("PerformanceMonitor");
		MeasurementStart = ModulePerformanceMonitor.StartTimeMeasurement();
	EndIf;
	
	Manager.OnFillToDoList(ToDoList);
	If Common.SubsystemExists("StandardSubsystems.PerformanceMonitor")
		AND ToDoList.Count() <> UserTasksCount Then
		UserTasksCount = ToDoList.Count();
		LastUserTask = ToDoList.Get(UserTasksCount - 1);
		Owner = LastUserTask.Owner;
		If TypeOf(Owner) = Type("MetadataObject") Then
			UserTaskPresentation = LastUserTask.Presentation;
		Else
			OwnerDetails = ToDoList.Find(LastUserTask.Owner, "ID");
			If OwnerDetails = Undefined Then
				UserTaskPresentation = LastUserTask.Presentation;
			Else
				UserTaskPresentation = OwnerDetails.Presentation;
			EndIf;
		EndIf;
		
		KeyOperation = "ToDosUpdate." + UserTaskPresentation;
		ModulePerformanceMonitor.EndTimeMeasurement(KeyOperation, MeasurementStart);
	EndIf;
EndProcedure

#EndRegion
