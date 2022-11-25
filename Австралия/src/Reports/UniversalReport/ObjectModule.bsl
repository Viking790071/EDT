#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

#Region ForCallsFromOtherSubsystems

// StandardSubsystems.ReportsOptions

// The settings of the common report form of the "Reports options" subsystem.
//
// Parameters:
//   Form - ClientApplicationForm, Undefined - a report form or a report settings form.
//       Undefined when called without a context.
//   OptionKey - String, Undefined - a name of a predefined report option or a UUID of a 
//       user-defined report option.
//       Undefined when called without a context.
//   Settings - Structure -
//       
//       * GenerateImmediately - Boolean - the default value for the "Generate immediately" check box.
//           If the check box is enabled, the report will be generated:
//             - After opening;
//             - After selecting user settings;
//             - After selecting another report option.
//       
//       * OutputSelectedCellTotal - Boolean - If True, the report will contain the autosum field.
//       
//       * ParametersPeriodicityMap - Map - restriction of the selection list of the StandardPeriod fields.
//           ** Key - DataCompositionParameter - a report parameter name to which restrictions are applied.
//           ** Value - EnumRef.AvailableReportPeriods - the report period bottom limit.
//       
//       * Print - Structure - default print settings of a spreadsheet document.
//           ** TopMargin - Number - the top margin for printing (in millimeters).
//           ** LeftMargin  - Number - the left margin for printing (in millimeters).
//           ** BottomMargin  - Number - the bottom margin for printing (in millimeters).
//           ** RightMargin - Number - the right margin for printing (in millimeters).
//           ** PageOrientation - PageOrientation - "Portrait" or "Landscape".
//           ** FitToPage - Boolean - automatically scale to  page size.
//           ** PrintScale - Number - image scale (percentage).
//       
//       * Events - Structure - events that have handlers defined in the report object module.
//           
//           ** OnGenerateAtServer - Boolean - if True, then the event handler must be defined in 
//               the report object module according to the following template:
//               
//               // Called in the event handler of the report form after executing the form code.
//               //
//               // Parameters:
//               //   Form - ClientApplicationForm - a report form.
//               //   Cancel - passed from the handler parameters "as it is".
//               //   StandardProcessing - passed from the handler parameters "as it is".
//               //
//               // See also:
//               //   "ClientApplicationForm.OnCreateAtServer" in Syntax Assistant.
//               //
//               // Example 1 - Adding a command with a handler to  ReportsClientOverridable.CommandHandler:
//               //\Command = From.Commands.Add("MySpecialCommand");
//               //	Command.Action  = "Attachable_Command";
//               //	Command.Header = NStr("en = 'MyCommand...'");
//               //	
//               //	Button = Form.Items.Add(Command.Name, Type("FormButton"), Form.Items.<SubmenuName>);
//               //	Button.CommandName = Command.Name;
//               //	
//               //	Form.ConstantCommands.Add(CommandCreate.Name);
//               //
//               Procedure OnGenerateAtServer(Form, Cancel, StandardProcessing) Export
//               	// Handling an event.
//               EndProcedure
//           
//           ** BeforeLoadOptionAtServer - Boolean - if True, then the event handler must be defined 
//               in the report object module according to the following template:
//               
//               // Called in the event handler of the report form after executing the form code.
//               //
//               // Parameters:
//               //   Form - ClientApplicationForm - a report form.
//               //   NewDCSettings - DataCompositionSettings - Settings to load to the settings composer.
//               //
//               // See also:
//               //   "Managed form extension for reports.OnLoadOptionAtServer" in Syntax Assistant.
//               //
//               Procedure BeforeLoadOptionAtServer(Form, NewDCSettings) Export
//               	// Handling an event.
//               EndProcedure
//           
//           ** OnLoadOptionAtServer - Boolean - if True, then the event handler must be defined in 
//               the report object module according to the following template:
//               
//               // Called in the event handler of the report form after executing the form code.
//               //
//               // Parameters:
//               //   Form - ClientApplicationForm - a report form.
//               //   NewDCSettings - DataCompositionSettings - Settings to load to the settings composer.
//               //
//               // See also:
//               //   "Managed form extension for reports.OnLoadOptionAtServer" in Syntax Assistant.
//               //
//               Procedure OnLoadOptionAtServer(Form, NewDCSettings) Export
//               	// Handling an event.
//               EndProcedure
//           
//           ** OnLoadUserSettingsAtServer - Boolean - if True, then the event handler must be 
//               defined in the report object module according to the following template:
//               
//               // Called in the event handler of the report form after executing the form code.
//               //
//               // Parameters:
//               //   Form - ClientApplicationForm - a report form.
//               //   NewDataCompositionUserSettings - DataCompositionUserSettings -
//               //       User settings to be imported to the settings composer.
//               //
//               // See also:
//               //   "Managed form extension for reports.OnLoadUserSettingsAtServer"
//               //    in Syntax Assistant.
//               //
//               Procedure OnLoadUserSettingsAtServer(Form, NewDataCompositionUserSettings) Export
//               	// Handling an event.
//               EndProcedure
//           
//           ** BeforeFillQuickSettingsPanel - Boolean - If True, define the event handler in the 
//               report object module using the following template:
//               
//               // The procedure is called before refilling the report form settings panel.
//               //
//               // Parameters:
//               //   Form - ClientApplicationForm - a report form.
//               //   FillingParameters - Structure - parameters to be loaded to the report.
//               //
//               Procedure BeforeFillQuickSettingsPanel(Form, FillingParameters) Export
//               	// Handling an event.
//               EndProcedure
//           
//           ** AfterFillQuickSettingsPanel - Boolean - if True, then the event handler must be 
//               defined in the report object module according to the following template:
//               
//               // The procedure is called after refilling the report form settings panel.
//               //
//               // Parameters:
//               //   Form - ClientApplicationForm - a report form.
//               //   FillingParameters - Structure - parameters to be loaded to the report.
//               //
//               Procedure AfterFillQuickSettingsPanel(Form, FillingParameters) Export
//               	// Handling an event.
//               EndProcedure
//           
//           ** ContextServerCall - Boolean - If True, define the event handler in the report object 
//               module using the following template:
//               
//               // Context server call handler.
//               //   Allows to execute a context server call from the client common module when you need it.
//               //   For example, from ReportsClientOverridable.CommandHandler().
//               //
//               // Parameters:
//               //   Form  - ClientApplicationForm
//               //   Key      - String    - a key of an operation that needs to be executed in the context call.
//               //   Parameters - Structure - server call parameters.
//               //   Result - Structure - the result of server operations, it is returned to the client.
//               //
//               // See also:
//               //   CommonForm.ReportForm.ExecuteContextServerCall().
//               //
//               Procedure ContextServerCall(Form, Key, Parameters, Result) Export
//               	// Handling an event.
//               EndProcedure
//           
//           ** OnDefineChoiceParameters - Boolean - if True, then the event handler must be defined 
//               in the report object module according to the following template:
//               
//               // The procedure is called in the report form before outputting the setting.
//               //   See more in ReportsOverridable.OnDefineChoiceParameters(). 
//               //
//               Procedure OnDefineChoiceParameters(Form, SettingProperties) Export
//               	// Handling an event.
//               EndProcedure
//           
//           ** SupplementMetadateObjectsConnections - Boolean - if True, then the event handler 
//               must be defined in the report object module according to the following template:
//               
//               // Additional links of the report settings.
//               //   See more in ReportsOverridable.SupplementMetadateObjectsConnections(). 
//               //
//               Procedure SupplementMetadateObjectsConnections(MetadataObjectsLinks) Export
//               	// Handling an event.
//               EndProcedure
//
Procedure DefineFormSettings(Form, OptionKey, Settings) Export
	
	Settings.Events.BeforeLoadVariantAtServer       = True;
	Settings.Events.OnDefineSelectionParameters        = True;
	Settings.Events.BeforeImportSettingsToComposer    = True;
	
EndProcedure

// See ReportsOverridable.OnDefineChoiceParameters. 
Procedure OnDefineSelectionParameters(Form, SettingProperties) Export
	
	If SettingProperties.Type = "SettingsParameterValue" Then
		ParameterName = String(SettingProperties.DCField);
		If ParameterName = "DataParameters.MetadataObjectType" Then
			SettingProperties.RestrictSelectionBySpecifiedValues = True;
			SettingProperties.ValuesForSelection = Reports.UniversalReport.AvailableMetadataObjectsTypes();
		ElsIf ParameterName = "DataParameters.MetadataObjectName" Then
			SettingProperties.RestrictSelectionBySpecifiedValues = True;
			SettingProperties.ValuesForSelection = Reports.UniversalReport.AvailableMetadataObjects(SettingsComposer.Settings);
		ElsIf ParameterName = "DataParameters.TableName" Then
			SettingProperties.RestrictSelectionBySpecifiedValues = True;
			SettingProperties.ValuesForSelection = Reports.UniversalReport.AvailableTables(SettingsComposer.Settings);
		EndIf;
	EndIf;
	
EndProcedure

// This procedure is called in the OnLoadVariantAtServer event handler of a report form after executing the form code.
// See "Managed form extension for reports.BeforeLoadOptionAtServer" in Syntax Assistant.
//
// Parameters:
//   Form - ClientApplicationForm - a report form.
//   NewDCSettings - DataCompositionSettings - settings to load into the settings composer.
//
Procedure BeforeLoadVariantAtServer(Form, NewDCSettings) Export
	// For the platform
	NewSchemaKey = Undefined;
	NewSchema = Undefined;
	
	IsImportedSchema = False;
	
	If TypeOf(NewDCSettings) = Type("DataCompositionSettings") Or NewDCSettings = Undefined Then
		If NewDCSettings = Undefined Then
			AuxSettingsProperties = SettingsComposer.Settings.AdditionalProperties;
		Else
			AuxSettingsProperties = NewDCSettings.AdditionalProperties;
		EndIf;
		
		If Form.ReportFormType = ReportFormType.Main
			AND (Form.DetailsMode
			Or (Form.CurrentVariantKey <> "Main"
			AND Form.CurrentVariantKey <> "Main")) Then 
			
			AuxSettingsProperties.Insert("ReportInitialized", True);
		EndIf;
		
		ImportedSchema = CommonClientServer.StructureProperty(AuxSettingsProperties, "DataCompositionSchema");
		If TypeOf(ImportedSchema) = Type("BinaryData") Then
			IsImportedSchema = True;
			NewSchemaKey = BinaryDataHash(ImportedSchema);
			NewSchema = Reports.UniversalReport.ExtractSchemaFromBinaryData(ImportedSchema);
		EndIf;
	EndIf;
	
	If IsImportedSchema Then
		SchemaKey = NewSchemaKey;
		ReportsServer.AttachSchema(ThisObject, Form, NewSchema, SchemaKey);
	EndIf;
	
EndProcedure

// Called before importing new settings. Used to change composition schema.
//   For example, if the report schema depends on the option key or report parameters.
//   For the schema changes to take effect, call the ReportsServer.EnableSchema() method.
//
// Parameters:
//   Context - Arbitrary -
//       The context parameters where the report is used.
//       Used to pass the ReportsServer.EnableSchema() method in the parameters.
//   SchemaKey - String -
//       An ID of the current setting composer schema.
//       It is not filled in by default (that means, the composer is initialized according to the main schema).
//       It is used for optimization to reinitialize the composer as rarely as possible).
//       It is possible not to use it if the initialization is running unconditionally.
//   VariantKey - String, Undefined - 
//       predefined report option name or UUID of a custom one.
//       Undefined when called for a details option or without context.
//   NewDCSettings - DataCompositionSettings, Undefined -
//       Settings for the report option that will be imported into the settings composer after it is initialized.
//       Undefined when option settings do not need to be imported (already imported earlier).
//   NewDCUserSettings - DataCompositionUserSettings, Undefined -
//       User settings that will be imported into the settings composer after it is initialized.
//       Undefined when user settings do not need to be imported (already imported earlier).
//
// Example:
//  // The report composer is initialized based on the schema from common templates:
//	If SchemaKey <> "1" Then
//		SchemaKey = "1";
//		DCSchema = GetCommonTemplate("MyCommonCompositionSchema");
//		ReportsServer.EnableSchema(ThisObject, Context, DCSchema, SchemaKey);
//	EndIf
//
//  // The schema depends on the parameter value that is displayed in the report user settings:
//	If ValueType(NewDCSettings) = Type("DataCompositionUserSettings") Then
//		MetadataObjectName = "";
//		For Each DCItem From NewDCUserSettings.Items Loop
//			If ValueType(DCItem) = Type("DataCompositionSettingsParameterValue") Then
//				ParameterName = String(DCItem.Parameter);
//				If ParameterName = "MetadataObject" Then
//					MetadataObjectName = DCItem.Value;
//				EndIf
//			EndIf
//		EndDo;
//		If SchemaKey <> MetadataObjectName Then
//			SchemaKey = MetadataObjectName;
//			DCSchema = New DataCompositionSchema;
//			// Filling the schema...
//			ReportsServer.EnableSchema(ThisObject, Context, DCSchema, SchemaKey);
//		EndIf
//	EndIf
//
Procedure BeforeImportSettingsToComposer(Context, SchemaKey, OptionKey, NewDCSettings, NewDCUserSettings) Export
	NewSchemaKey = Undefined;
	NewSchema = Undefined;
	
	IsImportedSchema = False;
	
	If TypeOf(NewDCSettings) = Type("DataCompositionSettings") Or NewDCSettings = Undefined Then
		If NewDCSettings = Undefined Then
			OptionKey = "Main";
			NewDCSettings = SettingsComposer.Settings;
			AuxSettingsProperties = SettingsComposer.Settings.AdditionalProperties;
		Else
			AuxSettingsProperties = NewDCSettings.AdditionalProperties;
		EndIf;
		ImportedSchema = CommonClientServer.StructureProperty(AuxSettingsProperties, "DataCompositionSchema");
		If TypeOf(ImportedSchema) = Type("BinaryData") Then
			IsImportedSchema = True;
			NewSchemaKey = BinaryDataHash(ImportedSchema);
			If NewSchemaKey <> SchemaKey Then
				NewSchema = Reports.UniversalReport.ExtractSchemaFromBinaryData(ImportedSchema);
			EndIf;
		EndIf;
	EndIf;
	
	If NewSchemaKey = Undefined Then // Not imported schema.
		
		If TypeOf(NewDCSettings) = Type("DataCompositionSettings") Then
			DCSettings = NewDCSettings;
		Else
			DCSettings = SettingsComposer.Settings;
		EndIf;
		
		ReportParameters = Reports.UniversalReport.ReportParameters(DCSettings, NewDCUserSettings);
		
		NewSchemaKey = ReportParameters.MetadataObjectType
			+ "/" + ReportParameters.MetadataObjectName
			+ "/" + ReportParameters.TableName;
		NewSchemaKey = Common.TrimStringUsingChecksum(NewSchemaKey, 100);
		
		If NewSchemaKey <> SchemaKey Or ReportParameters.ClearStructure Then
			SchemaKey = "";
			NewSchema = Reports.UniversalReport.GetStandardSchema(ReportParameters, DCSettings, NewDCUserSettings);
		EndIf;
		
	EndIf;
	
	If NewSchemaKey <> Undefined AND SchemaKey <> NewSchemaKey Then
		SchemaKey = NewSchemaKey;
		ReportsServer.AttachSchema(ThisObject, Context, NewSchema, SchemaKey);
		If IsImportedSchema Then
			Reports.UniversalReport.ImportedSchemaDefaultDCSettings(ThisObject, ImportedSchema, NewDCSettings, NewDCUserSettings);
		Else
			Reports.UniversalReport.DCSettingsByStandardSchemaDefault(ThisObject, ReportParameters, NewDCSettings, NewDCUserSettings);
		EndIf;
		
		If TypeOf(Context) = Type("ClientApplicationForm") Then
			// Call an overridable module.
			ReportsOverridable.BeforeLoadVariantAtServer(Context, NewDCSettings);
			BeforeLoadVariantAtServer(Context, NewDCSettings);
		EndIf;
		
	EndIf;
	
EndProcedure

// End StandardSubsystems.ReportsOptions

#EndRegion

#EndRegion

#Region Private

// Returns binary data hash.
//
// Parameters:
//   BinaryData - BinaryData - data, from which hash is calculated.
//
Function BinaryDataHash(BinaryData)
	DataHashing = New DataHashing(HashFunction.MD5);
	DataHashing.Append(BinaryData);
	Return StrReplace(DataHashing.HashSum, " ", "") + "_" + Format(BinaryData.Size(), "NG=");
EndFunction

#EndRegion

#EndIf
