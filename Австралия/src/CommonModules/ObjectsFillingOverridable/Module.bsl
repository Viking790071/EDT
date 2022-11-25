#Region Public

// Determines the list of configuration objects in whose manager modules this procedure is available
// AddFillingCommands that generates object filling commands.
// See the help for the AddFillingCommands procedure syntax.
//
// Parameters:
//   Objects - Array - metadata objects (MetadataObject) with filling commands.
//
// Example:
//	Objects.Add(Metadata.Catalogs.Organizations);
//   
Procedure OnDefineObjectsWithFIllingCommands(Objects) Export
	
EndProcedure

// Called once to generate the list of FillingCommands filling commands when it is first needed. 
// After that, the result is cached by the module; return values are re-used.
// Here you can define filling commands shared by most configuration objects.
//
// Parameters:
//   FillingCommands - ValueTable - generated commands to be shown in the submenu.
//     
//     Common settings:
//       * ID - String - a command ID.
//     
//     Appearance settings:
//       * Presentation - String   - command presentation in a form.
//       * Importance - String - a submenu group in which the command is to be shown.
//                                    The following values are acceptable: "Important", "Ordinary", and "SeeAlso".
//       * Position - Number - position of the command in the submenu. It is used to set up a 
//                                    particular workplace.
//       * Picture      - Picture - a command picture.
//     
//     Visibility and availability settings:
//       * ParameterType - TypesDetails - types of objects that the command is intended for.
//       * VisibilityOnForms    - String - comma-separated names of forms on which the command is to be displayed.
//                                        Used when the command content is different for different forms.
//       * FunctionalOptions - String - comma-separated  names of functional options that define the command visibility.
//       * VisibilityConditions    - Array - defines the command visibility depending on the context.
//                                        To register conditions, use procedure
//                                        AttachableCommands.AddCommandVisibilityCondition().
//                                        The conditions are combined by "And".
//       * ChangesSelectedObjects - Boolean - defines whether the command is available in case a 
//                                        user is not authorized to edit the object.
//                                        If True, the button will be unavailable.
//                                        Optional. The default value is True.
//     
//     Execution process settings:
//       * MultipleChoice - Boolean, Undefined - if True, then the command supports multiple selection.
//             In this case, the parameter is passed via a list.
//             Optional. The default value is True.
//       * WriteMode - String - actions associated with object writing that are executed before the command handler.
//             ** "DoNotWrite" - do not write the object and pass the full form in the handler 
//                                       parameters instead of references. In this mode, we 
//                                       recommend that you operate directly with a form that is passed in the structure of parameter 2 of the command handler.
//             ** "WriteNewOnly" - write only new objects.
//             ** "Write" - write only new and modified objects.
//             ** "Post" - post documents.
//             Before writing or posting the object, users are asked for confirmation.
//             Optional. Default value is "Write".
//       * FilesOperationsRequired - Boolean - if True, in the web client, users are prompted to 
//             install the file system extension.
//             Optional. The default value is False.
//     
//     Handler settings:
//       * Manager - String - an object responsible for executing the command.
//       * FormName - String - name of the form to be retrieved for the command execution.
//             If Handler is not specified, the "Open" form method is called.
//       * FormParameters - Undefined, FixedStructure - optional. Form parameters specified in FormName.
//       * Handler - String - description of the procedure that handles the main action of the command.
//             Format "<CommonModuleName>.<ProcedureName>" is used when the procedure is in a common module.
//             Format "<ProcedureName>" is used in the following cases:
//               - If FormName is filled, a client procedure is expected in the module of the specified form.
//               - If FormName is not filled, a server procedure is expected in the manager module.
//       * AdditionalParameters - FixedStructure - optional. Parameters of the handler specified in Handler.
//   
//   Parameters - Structure - information about execution context.
//       * FormName - String - full name of the form.
//   
//   StandardProcessing - Boolean - if False, the "AddFillingCommands" event of the object manager 
//                                   is not called.
//
Procedure BeforeAddFillCommands(FillingCommands, Parameters, StandardProcessing) Export
	
EndProcedure

#EndRegion
