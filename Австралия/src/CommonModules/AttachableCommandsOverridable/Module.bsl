#Region Public

// Using the OnDefineAttachableCommandsKinds you can define the native kinds of attachable commands 
// in addition to those already listed in the standard package (print forms, reports and population commands).
//
// Parameters:
//   AttachableCommandsKinds - ValueTable - supported command kinds:
//       * Name         - String            - a command kind name. It must meet the requirements of 
//                                           naming variables and be unique (do not match the names of other kinds).
//                                           It can correspond to the name of the subsystem responsible for the output of these commands.
//                                           These names are reserved: Print, Reports, and ObjectsFilling.
//       * SubmenuName  - String            - a submenu name for placing commands of this kind on the object forms.
//       * Title - String - the name of the submenu that is displayed to a user.
//       * Picture    - Picture          - a submenu picture.
//       * Representation - ButtonRepresentation - a submenu representation mode.
//       * Order     - Number             - submenu order in the command bar of the form object in 
//                                           relation to other submenus. It is used when 
//                                           automatically creating a submenu in the object form.
//
// Example:
//
//	Kind = AttachableCommandsKinds.Add();
//	Kind.Name = Motivators;
//	Kind.SubmenuName = MotivatorsSubmenu;
//	Kind.Title = NStr(en = Motivators);
//	Kind.Picture = PicturesLib.Info;
//	Picture.Representation = ButtonRepresentation.PictureAndText;
//	
Procedure OnDefineAttachableCommandsKinds(AttachableCommandsKinds) Export
	
	
	
EndProcedure

// It allows you to expand the Settings parameter composition of the OnDefineSettings procedure in 
// the manager modules of reports and data processors included in the 
// AttachableReportsAndDataProcessors subsystem. Using it, reports and data processors can report 
// that they provide certain command types and interact with the subsystems through their application interface.
//
// When deploying the Print, Object filling, and Report options subsystems to the configuration, in 
// the Settings parameter of the OnDefineSettings procedure of the report and data processor manager 
// modules, a number of standard properties is predefined, in which you can set the following:
//   * Placement - Array - list configuration metadata objects (MetadataObject), to which this 
//                           report or data processor is attached.
//   * AddPrintCommands - Boolean - if you set True, the report (data processor) manager module has 
//                             the AddPrintCommands procedure, which is called by the "Print" 
//                             subsystem when displaying print commands in the objects listed in the Placement parameter. 
//                             It is equal to specifying this report (data processor) in the procedure
//                             PrintManagerOverridable.OnDefineObjectsWithPrintCommands.
//   * AddFillCommands - Boolean - if you set True, the report (data processor) manager module has 
//                             the AddFillCommands procedure, which is called by the "Object population" subsystem
//                             on output of the filling commands in objects that are listed in the Placement parameter.
//                             It is equal to specifying this report (data processor) in the procedure
//                             ObjectsFillingOverridable.OnDefineObjectsWithFillCommands.
//   * AddReportsCommands - Boolean - for reports only. If you set True, the report manager module 
//                             has the AddReportsCommands procedure, which is called by the
//                             Report options subsystem when generating a list of context reports 
//                             that are open directly from the object forms, listed in the Placement parameter. 
//                             It is equal to specifying this report in procedure
//                             ReportsOptionsOverridable.DefineObjectsWithReportCommands.
//   * SetUpReportsOptions - Boolean - for reports only. If you set True, the report manager module 
//                             has the SetUpReportsOptions procedure, which is called by subsystem
//                             Report options when receiving the list of options of this report.
//                             For more information see ReportsOptionsOverridable. CustomizeReportsOptions.
//   * DefineFormSettings - Boolean - only for the reports attached to the ReportForm common form.
//                             If you set True, report object module has procedure
//                             DefineFormSettings defined. This procedure is called by the Object 
//                             options subsystem to override the standard kind and behavior of the ReportForm report form.
//                             For more information see ReportsOptionsOverridable. CustomizeReportsOptions.
//
// If the configuration does not have one of the "Print", "Object filling" and "Report 
// options"subsystems, the corresponding properties in the Settings parameter are also missing.
//
// Parameters:
//   InterfaceSettings - ValueTable - to add a new property to the Settings parameter of the
//                                                       OnDefineSettings procedure of report and 
//                                                       data processor manager modules, included to 
//                                                       the AttachableReportsAndDataProcessors subsystem, add a table row with the following columns:
//       * Key              - String        - a setting name, for example, AddMotivators.
//       * TypesDetails     - TypesDetails - the setting type, for example, New TypesDetails("Boolean").
//       * AttachableObjectsKinds - String - a name of metadata object kinds, for which this setting 
//                                             will be available, comma-separated. For example, "Report" or "Report, Data processor".
//
// Example:
//  To provide your own flag AddMotivators in the OnDefineSettings of the data processor module:
//  Procedure OnDefineSettings(Settings) Export
//    Settings.AddMotivators = True; // the procedure AddMotivators is called
//    Settings.Placement.Add(Metadata.Documents.Questionnaires);
//  EndProcedure implement the following code:
//
//  
//  Setting = InterfaceSettings.Add();
//  Setting.Key = "AddMotivators";
//  Setting.TypesDetails = New TypesDetails("Boolean");
//  Setting.AttachableObjectsKinds = "DataProcessor";
//
Procedure OnDefineAttachableObjectsSettingsComposition(InterfaceSettings) Export
	
	
	
EndProcedure

// It is called once during the first generation of the list of commands that are output in the form of a specific configuration object.
// Return the list of added commands in the Commands parameter.
// The result is cached using a module with repeated use of return values (by form names).
//
// Parameters:
//   FormSettings - Structure - information about the form where the commands are output. For reading.
//         * FormName - String - a full name of the form, where the attachable commands are output.
//                               For example, "Document.Questionnaire.ListForm".
//   
//   Sources - ValuesTree - information about the command providers of this form.
//         The second tree level can contain sources that are registered automatically when the owner is registered.
//         For example, journal register documents.
//         * Metadata - MetadataObject - object metadata.
//         * FullName  - String           - a full object name. For example: "Document.DocumentName".
//         * Kind        - String           - an object kind in uppercase. For example, "CATALOG".
//         * Manager   - Arbitrary     - an object manager module or Undefined if the object does 
//                                           not have a manager module or if it could not be received.
//         * Ref     - CatalogRef.MetadataObjectIDs - a reference to the metadata object.
//         * IsDocumentJournal - Boolean - True if the object is a document journal.
//         * DataRefType     - Type, TypesDetails - an item reference type.
//   
//   AttachedReportsAndDataProcessors - ValueTable - reports and data processors, providing their 
//         commands for the Sources objects:
//         * FullName - String       - a full name of a metadata object.
//         * Manager  - Arbitrary - a metadata object manager module.
//         See column content in AttachableCommandsOverridable.OnDefineAttachableObjectsSettingsComposition.
//   
//   Commands - ValueTable - write to this parameter the generated commands for output in submenu:
//       * Kind - String - a command kind.
//           See more in AttachableCommandsOverridable.OnDefineAttachableCommandsKinds. 
//       * ID - String - a command ID.
//       
//     Appearance settings:
//       * Presentation - String   - command presentation in a form.
//       * Importance      - String   - a suffix of a submenu group, in which the command is to be output.
//                                    The following values are acceptable: "Important", "Ordinary", and "SeeAlso".
//       * Order       - Number    - a command position in the group. It is used to set up a 
//                                    particular workplace. Can be specified in the range from 1 to 100. The default position is 50.
//       * Picture      - Picture - a command picture. Optional.
//       * Shortcut - Shortcut - a shortcut for fast command call. Optional.
//     
//     Visibility and availability settings:
//       * ParameterType - TypesDetails - types of objects that the command is intended for.
//       * VisibilityOnForms    - String - comma-separated names of forms on which the command is to be displayed.
//                                        Used when the command content is different for different forms.
//       * Purpose          - String - defines kinds of forms, for which the command is intended.
//                                        Available values:
//                                         "ForList" - show the command only as a list,
//                                         "ForObject" - show the command only as an object.
//                                        If the parameter is not specified, the command is intended for all kinds of forms.
//       * FunctionalOptions - String - comma-separated  names of functional options that define the command visibility.
//       * VisibilityConditions    - Array - defines the command visibility depending on the context.
//                                        To register conditions, use procedure
//                                        AttachableCommands.AddCommandVisibilityCondition().
//                                        The conditions are combined by "And".
//       * ChangesSelectedObjects - Boolean - defines whether the command is available in case a 
//                                        user is not authorized to edit the object.
//                                        If True, the button will be unavailable.
//                                        Optional. The default value is False.
//     
//     Execution process settings:
//       * MultipleChoice - Boolean - if True, the command supports multiple selection.
//             In this case, the parameter is passed via a list.
//             Optional. The default value is True.
//       * WriteMode - String - actions associated with object writing that are executed before the command handler.
//             ** "DoNotWrite" - do not write the object and pass the full form in the handler 
//                                          parameters instead of references. In this mode, we 
//                                          recommend that you operate directly with a form that is passed in the structure of parameter 2 of the command handler.
//             ** "WriteNewOnly" - write only new objects.
//             ** "Write" - write only new and modified objects.
//             ** "Post" - post documents.
//             Before writing or posting the object, users are asked for confirmation.
//             Optional. Default value is "Write".
//       * FilesOperationsRequired - Boolean - if True, in the web client, users are prompted to 
//             install the file system extension. Optional. The default value is False.
//     
//     Handler settings:
//       * Manager - String - an object responsible for executing the command.
//       * FormName - String - name of the form to be retrieved for the command execution.
//           If Handler is not specified, the "Open" form method is called.
//       * FormParameterName - String - a name of the form parameter to which a reference or a reference array is to be passed.
//       * FormParameters - Undefined, Structure - parameters of the form, specified in the FormName. Optional.
//       * Handler - String - details of the procedure that handles the main command action, in the kind of:
//           "<CommonModuleName>.<ProcedureName>" if the procedure is placed in a common module;
//           or "<ProcedureName>" is used in the following cases:
//             - if FormName is filled, a client procedure is expected in the  specified form module.
//             - if FormName is not filled, a server procedure is expected in the manager module.
//       * AdditionalParameters - Structure - parameters of the handler, specified in the Handler. Optional.
//
Procedure OnDefineCommandsAttachedToObject(FormSettings, Sources, AttachedReportsAndDataProcessors, Commands) Export
	
	
	
EndProcedure

#EndRegion
