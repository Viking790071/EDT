#Region Public

// It is called before searching for objects marked for deletion.
// In this handler, you can organize deletion of obsolete dimension keys and any other infobase 
// objects that you no longer need.
//
// Parameters:
//   Parameters - Structure - with the following properties:
//     * Interactive - Boolean - True if deletion of marked objects is started by a user.
//                                False if deletion is started on the job schedule.
//
Procedure BeforeSearchForItemsMarkedForDeletion(Parameters) Export
	
EndProcedure

#EndRegion
