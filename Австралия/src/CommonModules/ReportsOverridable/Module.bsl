#Region Public

// In this procedure, describe additional dependencies of configuration metadata objects that will 
//   be used to connect report settings.
//
// Parameters:
//   MetadataObjectsLinks - ValueTable - Links table.
//       * SubordinateAttribute - String - attribute name of a subordinate metadata object.
//       * SubordinateType      - Type    - subordinate metadata objectt type.
//       * MasterType          - Type    - leading metadata object type.
//
Procedure AddMetadataObjectsConnections(MetadataObjectsLinks) Export
	
	
	
EndProcedure

// It is called in the report form and in the report setting form before outputting a setting to 
// specify additional selection parameters.
//
// Parameters:
//   Form - ClientApplicationForm, Undefined - a report form.
//   SettingProperties - Structure - a description of report setting that will be output as a report form.
//     * DCField        - DataCompositionField - an outputted setting.
//     * TypesDetails - TypesDetails        - A type of a setting for output.
//     * ValuesForSelection - ValueList - specify objects that will be offered to a user in the choice list.
//           The parameter adds items to the list of objects previously selected by a user.
//           However, do not assign a new value list to this parameter.
//     * SelectionValuesQuery - Query - specify a query to select objects that are required to be added into
//           ValuesForSelection. As the first column (with 0 index), select the object, that has to 
//           be added to the ValuesForSelection.Value.
//           To disable autofilling, write a blank string to the SelectionValuesQuery.Text property.
//     * RestrictSelectionBySpecifiedValues - Boolean - specify True to restrict user selection with 
//           values specified in ValuesForSelection (its final state).
//
// Example:
//   1. For all settings of the CatalogRef.Users type, hide and do not permit to select users marked 
//   for deletion, as well as unavailable and internal ones.
//
//   If SettingProperties.TypesDetails.ContainsType(Type("CatalogRef.Users")) Then
//     SettingProperties.RestrictSelectionBySpecifiedValues = True;
//     SettingProperties.ValuesForSelection.Clear();
//     SettingProperties.SelectionValuesQuery.Text =
//       "SELECT Reference FROM Catalog.Users
//       |WHERE NOT DeletionMark AND NOT Unavailable AND NOT Internal";
//   EndIf
//
//   2. Provide an additional value for selection for the Size setting.
//
//   If SettingProperties.DCField = New DataCompositionField("DataParameters.Size") Then
//     SettingProperties.ValuesForSelection.Add(10000000, NStr("en = 'Over 10 MB'"));
//   EndIf
//
Procedure OnDefineSelectionParameters(Form, SettingProperties) Export
	
EndProcedure

// This procedure is called in the OnLoadVariantAtServer event handler of a report form after executing the form code.
// See "ClientApplicationForm.OnGenerateAtServer" in Syntax Assistant and ReportsClientOverridable.CommandHandler.
//
// Parameters:
//   Form - ClientApplicationForm - a report form.
//   Cancel - Boolean - indicates that form creation was canceled.
//   StandardProcessing - Boolean - a flag of standard (system) event processing execution.
//
// Example:
//	//Adding a command with a handler to ReportsClientOverridable.CommandHandler:
//	Command = ReportForm.Commands.Add("MySpecialCommand");
//	Command.Action  = "Attachable_Command";
//	Command.Header = NStr("en = 'My command...'");
//	
//	Button = ReportForm.Items.Add(Command.Name, Type("FormButton"), ReportForm.Items.<SubmenuName>);
//	Button.CommandName = Command.Name;
//	
//	ReportForm.ConstantCommands.Add(CreateCommand.Name);
//
Procedure OnCreateAtServer(Form, Cancel, StandardProcessing) Export
	
	Form.Items.QuickSettings.BackColor = StyleColors.QuickSettingsGroupBackground;
	Form.Items.ReportSpreadsheetDocument.ViewScalingMode = ViewScalingMode.Normal;
	
EndProcedure

// The procedure is called in the same name event handler of the report form and report setup form.
// See "Managed form extension for reports.BeforeLoadOptionAtServer" in Syntax Assistant.
//
// Parameters:
//   Form - ClientApplicationForm - a report form or a report settings form.
//   NewDCSettings - DataCompositionSettings - settings to load into the settings composer.
//
Procedure BeforeLoadVariantAtServer(Form, NewDCSettings) Export
	
	
	
EndProcedure

// In this procedure, describe additional dependencies of configuration metadata objects that will 
//   be used to connect report settings.
//
// Parameters:
//   MetadataObjectsLinks - ValueTable - Links table.
//       * SubordinateAttribute - String - attribute name of a subordinate metadata object.
//       * SubordinateType      - Type    - subordinate metadata objectt type.
//       * MasterType          - Type    - leading metadata object type.
//
Procedure SupplementMetadateObjectsConnections(MetadataObjectsLinks) Export
	
	
	
EndProcedure

#EndRegion
