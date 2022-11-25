#Region Public

// Returns an array of command interface subsystems containing the passed metadata object.
// 
//
// Parameters:
//  MetadataObjectName - String - a full name of a metadata object.
//
// Returns:
//  Array - an array of command interface subsystems.
//
Function SectionsForObject(MetadataObjectName) Export
	ObjectsBelonging = ToDoListInternalCached.ObjectsBelongingToCommandInterfaceSections();
	
	CommandInterfaceSubsystems = New Array;
	SubsystemNames                 = ObjectsBelonging.Get(MetadataObjectName);
	If SubsystemNames <> Undefined Then
		For Each SubsystemName In SubsystemNames Do
			CommandInterfaceSubsystems.Add(Metadata.FindByFullName(SubsystemName));
		EndDo;
	EndIf;
	
	If CommandInterfaceSubsystems.Count() = 0 Then
		CommandInterfaceSubsystems.Add(DataProcessors.ToDoList);
	EndIf;
	
	Return CommandInterfaceSubsystems;
EndFunction

// Determines whether it is necessary to display a to-do in the user's to-do list.
//
// Parameters:
//  UserTaskID - String - ID of a to-do to search for in the disabled to-to list.
//
// Returns:
//  Boolean - True if a to-do was disabled programmatically and it should not be shown to the user.
//
Function UserTaskDisabled(UserTaskID) Export
	UserTasksToDisable = New Array;
	ToDoListOverridable.OnDisableToDos(UserTasksToDisable);
	
	Return (UserTasksToDisable.Find(UserTaskID) <> Undefined)
	
EndFunction

// Returns a structure of common values used for calculating current to-dos.
//
// Returns:
//  Structure - with the following properties:
//    * User - CatalogRef.Users, CatalogRef.ExternalUsers - a current user.
//    * IsFullUser - Boolean - True if a user has full access.
//    * CurrentDate - Date - a current session date.
//    * BlankDate - Date - a blank date.
//
Function CommonQueryParameters() Export
	Return ToDoListInternal.CommonQueryParameters();
EndFunction

// Sets common query parameters to calculate the current to-dos.
//
// Parameters:
//  Query - Query - a running query with common parameters to be filled in.
//                                       
//  CommonQueryParameters - Structure - common values for calculating indicators.
//
Procedure SetQueryParameters(Query, CommonQueryParameters) Export
	ToDoListInternal.SetCommonQueryParameters(Query, CommonQueryParameters);
EndProcedure

// Gets numeric values of to-dos from a passed query.
//
// Query with data must have only one string with an arbitrary number of fields.
// Values of such fields must be values of matching indicators.
//
// For example, such a query might be as follows -
//   SELECT
//      COUNT(*) AS <Name of a predefined item being a document quantity indicator>.
//   FROM
//      Document.<Document name>.
//
// Parameters:
//  Query - Query - a running query.
//  CommonQueryParameters - Structure - common values for calculating current to-dos.
//
// Returns:
//  Structure - with the following properties:
//     * Key - String - a name of a current to-do indicator.
//     * Value - Number - a numerical indicator value.
//
Function NumericUserTasksIndicators(Query, CommonQueryParameters = Undefined) Export
	Return ToDoListInternal.NumericUserTasksIndicators(Query, CommonQueryParameters);
EndFunction

#EndRegion

