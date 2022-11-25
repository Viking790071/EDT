///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2019, 1C-Soft LLC
// All Rights reserved. This application and supporting materials are provided under the terms of 
// Attribution 4.0 International license (CC BY 4.0)
// The license text is available at:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////

#Region Public

// The procedure is called to update business process data in the BusinessesProcessData information register.
//
// Parameters:
//  Record - InformationRegisterRecord.BusinessesProcessData - a business process record.
//
Procedure OnWriteBusinessProcessesList(Record) Export
	
EndProcedure

// The procedure is called to check the rights for stopping and continuing a business process for 
// the current user.
//
// Parameters:
//  BusinessProcess        - BusinessProcessRef - a reference to a business process.
//  HasRights            - Boolean              - if False, the rights are denied.
//  StandardProcessing - Boolean              - if False, the standard rights check is skipped.
//
Procedure OnCheckStopBusinessProcessRights(BusinessProcess, HasRights, StandardProcessing) Export
	
EndProcedure

// The procedure is called to fill in the MainTask attribute from filling data.
//
// Parameters:
//  BusinessProcessObject  - BusinessProcessObject - a business process.
//  FillingData     - Arbitrary        - filling data that is passed to the filling handler.
//  StandardProcessing - Boolean              - if False, the standard filling processing is skipped.
//                                               
//
Procedure OnFillMainBusinessProcessTask(BusinessProcessObject, FillingData, StandardProcessing) Export
	
EndProcedure

// The function is called to fill in the task form parameters.
//
// Parameters:
//  BusinessProcessName           - String                         - a business process name.
//  TaskRef                - TaskRef.PerformerTask - a task.
//  BusinessProcessRoutePoint - BusinessProcessRoutePointRef.Job - an action.
//  FormParameters              - Structure                      - a description of task execution with the following properties:
//   * FormName       - a form name passed to the OpenForm method.
//   * FormParameters - parameters of the form to be opened.
//
// Example:
//  If BusinessProcessName = "Job" Then
//      FormName = "BusinessProcess.Job.Form.ExternalAction" + BusinessProcessRoutePoint.Name;
//      FormParameters.Insert("FormName", FormName);
//  EndIf;
//
Procedure OnReceiveTaskExecutionForm(BusinessProcessName, TaskRef,
	BusinessProcessRoutePoint, FormParameters) Export
	
EndProcedure

// Fills in the list of business processes that are attached to the subsystem and their manager 
// modules contain the following export procedures and functions:
//  - OnForwardTask.
//  - TaskExecutionForm.
//  - DefaultCompletionHandler.
//
// Parameters:
//   AttachedBusinessProcesses - Map - as a key, specify a full name of the metadata object attached 
//                                               to the Business processes and tasks subsystem.
//                                               As a value, specify an empty string.
//
// Example:
//   AttachedBusinessProcesses.Insert(Metadata.BusinessProcesses.JobWithRoleAddressing.FullName(), "");
//
Procedure OnDetermineBusinessProcesses(AttachedBusinessProcesses) Export
	
	
	
EndProcedure

// It is called from the BusinessProcessesAndTasks subsystem object modules to set up restriction 
// logic in the application.
//
// For the example of filling access value sets, see comments to AccessManagement.
// FillAccessValuesSets.
//
// Parameters:
//  Object - BusinessProcessObject.Job - an object for which the sets are populated.
//  
//  Table - ValueTable - returned by AccessManagement.AccessValuesSetsTable.
//
Procedure OnFillingAccessValuesSets(Object, Table) Export
	
	
	
EndProcedure

// It is called from the PerformersRoles catalog manager module upon initial filling of the 
// performer roles in the application.
//
// Parameters:
//  LanguageCodes - Array - a list of configuration languages. Applicable to multilanguage configurations.
//  Items   - ValueTable - filling data. Column content matches the attribute set of the 
//                                 ImplementersRoles catalog.
//
Procedure OnInitiallyFillPerformersRoles(LanguagesCodes, Items) Export
	
	
	
EndProcedure

// It is called from the PerformersRoles catalog manager module upon initial filling of the 
// performer role item in the application.
//
// Parameters:
//  Object                   - CatalogObject.ImplementersRoles - the object to be filled in.
//  Data                  - ValuesTableRow - filling data.
//  AdditionalParameters - Structure - Additional parameters.
//
Procedure AtInitialPerformerRoleFilling(Object, Data, AdditionalParameters) Export
	
	
	
EndProcedure

// It is called from the CCT TaskAddressingObjects manager module upon initial filling of task 
// addressing objects in the application.
// Standard attribute ValueType must be filled in the OnInitialFillingTaskAddressingObjectItem procedure.
//
// Parameters:
//  LanguageCodes - Array - a list of configuration languages. Applicable to multilanguage configurations.
//  Items   - ValueTable - filling data. Column composition matches the attribute set of CCT object TaskAddressingObjects.
//
Procedure OnInitialFillingTasksAddressingObjects(LanguagesCodes, Items) Export
	
	
	
EndProcedure

// It is called from the CCT TaskAddressingObjects manager module upon initial filling of task 
// addressing item in the application.
//
// Parameters:
//  Object                   - ChartOfCharacteristicTypesObject.ImplementersRoles - the object to be filled in.
//  Data                  - ValuesTableRow - filling data.
//  AdditionalParameters - Structure - Additional parameters.
//
Procedure OnInitialFillingTaskAddressingObjectItem(Object, Data, AdditionalParameters) Export
	
	
	
EndProcedure

#EndRegion
