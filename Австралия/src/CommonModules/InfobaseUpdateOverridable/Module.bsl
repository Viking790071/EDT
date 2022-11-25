#Region Public

// Overrides various messages displayed to a user.
// 
// Parameters:
//  Parameters - Structure - with the following properties:
//    * UpdateResultNotes - String - a tooltip text that contains the path to the "Application 
//                                          change log" form.
//    * UncompletedDeferredHandlersMessageParameters - Structure - message on availability of 
//                                          uncompleted deferred handlers that perform an update to 
//                                          a previous version; displayed on attempting migration.
//       * MessageText                 - String - text of a message displayed to a user. By default, 
//                                          message text is built to allow for its continuation, i.e. 
//                                          has a ProhibitContinuation = False parameter.
//       * MessagePicture              - PictureLib: Picture - a picture displayed on the left of a message.
//       * ProhibitContinuation - Boolean - if True, then continuation of an update will be impossible. The default value is False.
//    * ApplicationReleaseNotesLocation - String - provides location of a command used to open the 
//                                          form containing notes on an application release.
//    * MultiThreadUpdate - Boolean - if True, then several update handlers can operate at once.
//                                           The default value is False.
//                                          This influences both the number of update handlers 
//                                          execution threads and the number of update data registration threads.
//                                          NB: Before using, read documentation.
//    * DefaultInfobaseUpdateThreadCount - String - the number of deferred update threads used by 
//                                          default (if a constant value is not specified)
//                                          InfobaseUpdateThreadCount. Equals 1 by default.
//
Procedure OnDefineSettings(Parameters) Export
	
	
	
EndProcedure

// The procedure is called before the infobase data update handler procedures.
// You can implement any non-standard logic for data update: for instance, initialize information 
// about versions of subsystems using InfobaseUpdate.IBVersion, InfobaseUpdate.SetIBVersion, and 
// InfobaseUpdate.RegisterNewSubsystem.
// 
//
// Example:
//  To cancel a regular procedure of migration from another application, register the fact that the 
//  main configuration version is up-to-date:
//  SubsystemVersions = InfobaseUpdate.SubsystemVersions();
//  If SubsystemVersions.Count () > 0 And SubsystemVersions.Find(Metadata.Name, "SubsystemName") = Undefined Then
//    InfobaseUpdate.RegisterNewSubsystem(Metadata.Name, Metadata.Version);
//  EndIf
//
Procedure BeforeUpdateInfobase() Export
	
EndProcedure

// The procedure is called after the infobase data is updated.
// Depending on conditions, you can turn off regular opening of a form containing description of new 
// version updates at first launch of a program (right after an update), and also execute other 
// actions.
//
// It is not recommended to execute any kind of data processing in this procedure.
// Such procedures should be applied by regular update handlers executed for each "*" version.
// 
// Parameters:
//   PreviousIBVersion     - String - version before an update. "0.0.0.0" for an "empty" infobase.
//   CurrentIBVersion        - String - version after an update. As a rule, it corresponds with Metadata.Version.
//   UpdateIterations     - Array - an array of structures providing information on and keys for 
//                                     updates of each library or configuration:
//       * Subsystem              - String - name of a library or a configuration.
//       * Version                  - String - for example, "2.1.3.39". Library (configuration) version number.
//       * IsMainConfiguration - Boolean - True if it is a main configuration, not a library.
//       * Handlers             - ValueTable - all library update handlers; see description of 
//                                   columns in InfobaseUpdate.NewUpdateHandlerTable.
//       * CompletedHandlers - ValueTree - completed update handlers, library and version number; 
//                                   see description of columns in InfobaseUpdate.NewUpdateHandlerTable.
//       * MainServerModuleName - String - name of a library (configuration) module that contains 
//                                        basic information about it: name, version, etc.
//       * MainServerModule - CommonModule - library (configuration) common module which contains 
//                                        basic information about it: name, version, etc.
//       * PreviousVersion             - String - for example, "2.1.3.30". Library (configuration) version number before an update.
//   OutputUpdateDetails - Boolean - if False s set, a form containing description of new version 
//                                updates will not be opened at first launch of a program. Default value is True.
//   ExclusiveMode           - Boolean - indicates that an update was executed in an exclusive mode.
//
// Example:
//  To avoid completed update handlers:
//  For Every UpdateIteration From UpdateIterations Cycle
//  	For Every Version From UpdateIteration.CompletedHandlers.Rows Cycle
//  		
//  		If Version.Version = "*" Then
//  			// A group of handlers that are executed regularly, on every other version.
//  		Else
//  			// A group of handlers that were executed for a particular version
//  		EndIf
//  		
//  		For Each Handler In Version.Rows Do ...
//  			...
//  		EndDo;
//  		
//  	EndDo;
//  EndDo;
//
Procedure AfterUpdateInfobase(Val PreviousIBVersion, Val CurrentIBVersion,
	Val UpdateIterations, OutputUpdateDetails, Val ExclusiveMode) Export
	
	
EndProcedure

// Called on creating a document containing description of new version updates at first launch of a 
// program.
//
// Parameters:
//   Template - SpreadsheetDocument - description of new version updates automatically formed from 
//                               the ApplicationReleaseNotes  common template.
//                               A template can be programmatically modified or substituted with another one.
//
Procedure OnPrepareUpdateDetailsTemplate(Val Template) Export
	
EndProcedure

// Overrides the queue of deferred event handlers in the parallel execution mode.
//  Can be useful if deferred library handlers are processing same data as main configuration 
// handlers.
// For example, there are library and configuration handlers that are processing the 
// Counterparties catalog, and it is important that the configuration handler finishes first so that 
// data would be updated right. In this case, setting a new queue position number for a library 
// handler bigger than a configuration handler queue position number will solve the issue.
//
// Parameters:
//  HandlerAndQueue - Match - where:
//    * Key     - String - full name of an update handler.
//    * Value - Number - queue position number toset for a handler.
//
Procedure OnFormingDeferredHandlersQueues(HandlerAndQueue) Export
	
	
EndProcedure

#Region ObsoleteProceduresAndFunctions

// Obsolete. Called to get the list of the update handlers that should not be executed.
// You can only disable update handlers with a "*" version number.
//
// Parameters:
//  DetachableHandlers - ValueTable - containing columns:
//     * LibraryID - String - the configuration name or library ID.
//     * Version -                - String - number of a configuration version where you want to 
//                                          disable execution of a handler.
//     * Procedure -             - String - procedure name of an update handler that you want to 
//                                          disable.
//
// Example:
//   NewException = DetachableHandlers.Add();
//   NewException.LibraryID = "StandardSubsystems";
//   NewException.Version = "*";
//   NewException.Procedure - "ReportOptions.Update";
//
Procedure OnDetachUpdateHandlers(DetachableHandlers) Export
	
EndProcedure

#EndRegion

#EndRegion
