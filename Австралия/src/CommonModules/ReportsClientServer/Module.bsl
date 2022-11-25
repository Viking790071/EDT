#Region Public

// Default report form settings
//
// Returns:
//   Structure - report form settings:
//       
//       * GenerateImmediately - Boolean - the default value for the "Generate immediately" check box.
//           If the check box is enabled, the report will be generated:
//             - After opening;
//             - After selecting user settings;
//             - After selecting another report option.
//       
//       * OutputSelectedCellTotal - Boolean - If True, the report will contain the autosum field.
//       
//       * EditStructureAllowed - Boolean - if False, the Structure tab will be hidden in the report options.
//           If True, the Structure tab is shown for reports on DSC: in the extended mode, but also 
//           in the simple mode, if flags of using groups are output in user settings.
//       
//       * OptionChangesAllowed - Boolean - if False, the buttons of changing this report options are locked.
//           If the current user does not have the SaveUserData and Add rights
//           of the ReportsOptions directory, it is forcefully set to False.
//
//       * SelectAndEditOptionsWithoutSavingAllowed - Boolean - if it is True you can select and set 
//           predefined report options, but cannot save the settings you made.
//            For example, it can be specified for context reports (open with parameters) that have 
//           several options.
//
//       * ControlItemsPlacementParameters - Structure, Undefined - options:
//           - Undefined - parameters of common report form management items "by default".
//           - Structure - with setting names in the DataCompositionSettings collection of the 
//                         settings Property of DataCompositionSettingsComposer type:
//               ** Filter           - Array - the same as the next property has.
//               ** DataParameters - Structure - with the form field properties:
//                    *** Field                     - String - field name, whose presentation is being set.
//                    *** HorizontalStretch - Boolean - form field property value.
//                    *** AutoMaxWidth   - Boolean - form field property value.
//                    *** Width                   - Boolean - form field property value.
//
//            An example of determining the described parameter:
//
//               SettingsArray              = New Array;
//               ControlItemSettings = New Structure;
//               ControlItemSettings.Insert("Field",                     "RegistersList");
//               ControlItemSettings.Insert("HorizontalStretch", False);
//               ControlItemSettings.Insert("AutoMaxWidth",   True);
//               ControlItemSettings.Insert("Width",                   40);
//
//               SettingsArray.Add(ControlItemSettings);
//
//               ControlItemsSettings = New Structure();
//               ControlItemsSettings.Insert("DataParameters", SettingsArray);
//
//               Return ControlItemsSettings;
//
//       * HideBulkEmailCommands - Boolean - a flag that allows to hide bulk email commands to those 
//           reports, for which bulk email does not make sense.
//           True              - bulk email commands will be hidden,
//           False (default) - commands will be available.
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
//               //   Cancel - Boolean - indicates that form creation was canceled.
//               //      See description of the parameter with the same name "ClientApplicationForm.OnCreateAtServer" in Syntax Assistant.
//               //   StandardProcessing - Boolean - indicates that the standard (system) event processing is completed.
//               //      See description of the parameter with the same name "ClientApplicationForm.OnCreateAtServer" in Syntax Assistant.
//               //
//               // See also:
//               //   The procedure of outputting the added commands to the ReportsServer.OutputCommand() form.
//               //   Global handler of this event: ReportsOverridable.OnGenerateAtServer().
//               //
//               // An example of adding a command:
//               //	Command = Form.Commands.Add("<CommandName>");
//               //	Command.Action  = "Attachable_Command";
//               //	Command.Header = NStr("en = '<Command presentation...>'");
//               //	ReportsServer.OutputCommand(Form, Command, "<Compositor>");
//               // Command handler is written in the ReportsClientOverridable.CommandHandler procedure.
//               //
//               Procedure OnGenerateAtServer(Form, Cancel, StandardProcessing) Export
//               	// Handling an event.
//               EndProcedure
//           
//           ** BeforeImportSettingsToComposer - Boolean - If True, define the event handler in the 
//               report object module using the following template:
//               
//               // Called before importing new settings. Used to change composition schema.
//               //   For example, if the report schema depends on the option key or the report parameters.
//               //   For the schema changes to take effect, call the ReportsServer.EnableSchema() method.
//               //
//               // Parameters:
//               //   Context - Arbitrary -
//               //       The context parameters where the report is used.
//               //       Used to pass the ReportsServer.EnableSchema() method in the parameters.
//               //   SchemaKey - String -
//               //       The ID of the setting composer current schema.
//               //       It is not filled in by default (that means, the composer is initialized based on the main schema).
//               //       It is used for optimization to reinitialize the composer as rarely as possible.
//               //       It is possible not to use it if the initialization is running unconditionally.
//               //   OptionKey - String, Undefined -
//               //       The predefined report option name or UUID of a custom one.
//               //       Undefined when called for a details option or without context.
//               //   NewDCSettings - DataCompositionSettings, Undefined -
//               //       Settings for the report option that will be imported into the settings composer after it is initialized.
//               //       Undefined when option settings do not need to be imported (already imported earlier).
//               //   NewDataCompositionUserSettings - DataCompositionUserSettings, Undefined -
//               //       User settings that will be imported into the settings composer after it is initialized.
//               //       Undefined when user settings do not need to be imported (already imported earlier).
//               //
//               // Examples:
//               // 1. The report composer is initialized based on the schema from common templates:
//               //	If SchemaKey <> "1" Then
//               //		SchemaKey = "1";
//               //		DSChema = GetCommonTemplate("MyCommonCompositionSchema");
//               //		ReportsServer.EnableSchema(ThisObject, Context, DCSchema, SchemaKey);
//               //	EndIf;
//               //
//               // 2. The schema depends on the parameter value that is displayed in the report user settings:
//               //	If TypeOf(NewDataCompositionUserSettings) = Type("DataCompositionUserSettings") Then
//               //		FullMetadataObjectName = "";
//               //		For Each DCItem From NewDataCompositionUserSettings.Items Loop
//               //		\If TypeOf(DCItem) = Type("DataCompositionSettingsParameterValue") Then
//               //				ParameterName = String(DCItem.Parameter);
//               //				If ParameterName = "MetadataObject" Then
//               //					FullMetadataObjectName = DCItem.Value;
//               //				EndIf;
//               //			EndIf;
//               //		EndDo;
//               //		If SchemaKey <> FullMetadataObjectName Then
//               //			SchemaKey = FullMetadataObjectName;
//               //			DCSchema = New DataCompositionSchema;
//               //			// Filling schema...
//               //			ReportsServer.EnableSchema(ThisObject, Context, DCSchema, SchemaKey);
//               //		EndIf;
//               //	EndIf;
//               //
//               Procedure BeforeImportSettingsToComposer(Context, SchemaKey, OptionKey, NewDCSettings, NewDataCompositionUserSettings) Export
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
//               // See ReportsOverridable.BeforeLoadOptionAtServer(). 
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
//               // See "Managed form extension for reports.OnLoadOptionAtServer" Syntax Assistant in Syntax Assistant.
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
//               // See "Managed form extension for reports.OnLoadUserSettingsAtServer" Syntax Assistant
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
//           ** OnDefineChoiceParameters - Boolean - if True, then the event handler must be defined 
//               in the report object module according to the following template:
//               
//               // The procedure is called in the report form before outputting the setting.
//               //
//               // Parameters:
//               //   Form - ClientApplicationForm, Undefined - a report form.
//               //   SettingProperties - Structure - a description of report setting that will be output as a report form.
//               //       * TypesDetails - TypesDetails - Setting type.
//               //       * ValuesForSelection - ValueList - objects that will be offered to a user 
//                          in the choice list. The parameter adds items to the list of objects previously selected by a user.
//               //       * SelectionValuesQuery - Query - returns objects to complement ValuesForSelection.
//               //           As the first column (with 0m index) select the object,
//               //          that has to be added to the ValuesForSelection.Value.
//               //           To disable autofill
//               //          write a blank string to the  SelectionValuesQuery.Text property.
//               //       * RestrictSelectionBySpecifiedValues - Boolean - when it is True, user choice will be
//               //           restricted by values specified in ValuesForSelection (its final status).
//               //
//               // See also:
//               //   ReportsOverridable.OnDefineChoiceParameters().
//               //
//               Procedure OnDefineChoiceParameters(Form, SettingProperties) Export
//               	// Handling an event.
//               EndProcedure
//           
//           ** OnDefineUsedTables - Boolean - if True, then the event handler must be defined in 
//               the report object module according to the following template:
//               
//               // A list of registers and other metadata objects, by which report is generated.
//               //   It is used to check if the report can contain non-updated data.
//               //
//               // Parameters:
//               //   OptionKey - String, Undefined -
//               //       The predefined report option name or UUID of a custom one.
//               //       Undefined when called for a details option or without context.
//               //   UsedTables - Array from String -
//               //       Full metadata object names (registers, documents, and other tables),
//               //       whose data is displayed in the report.
//               //
//               // Example:
//               //	UsedTables.Add(Metadata.Documents.<DocumentName>.FullName());
//               //
//               Procedure OnDefineUsedTables(OptionKey, UsedTables) Export
//               	// Handling an event.
//               EndProcedure
//           
//           ** SupplementMetadateObjectsConnections - Boolean - if True, then the event handler 
//               must be defined in the report object module according to the following template:
//               
//               // Additional links of the report settings.
//               // In this procedure, describe additional dependencies of configuration metadata objects
//               //   that will be used to connect report settings.
//               //
//               // Parameters:
//               //   MetadataObjectsLinks - ValueTable - Links table.
//               //       * SubordinateAttribute - String - attribute name of a subordinate metadata object.
//               //       * SubordinateType      - Type    - subordinate metadata objectt type.
//               //       * MasterType          - Type    - leading metadata object type.
//               //
//               // See also:
//               //   ReportsOverridable.SupplementMetadateObjectsConnections().
//               //
//               Procedure SupplementMetadateObjectsConnections(MetadataObjectsLinks) Export
//               	// Handling an event.
//               EndProcedure
//
Function GetDefaultReportSettings() Export
	Settings = New Structure;
	Settings.Insert("GenerateImmediately", False);
	Settings.Insert("OutputSelectedCellsTotal", True);
	Settings.Insert("EditStructureAllowed", True);
	Settings.Insert("EditOptionsAllowed", True);
	Settings.Insert("SelectAndEditOptionsWithoutSavingAllowed", False);
	Settings.Insert("ControlItemsPlacementParameters"          , Undefined);
	Settings.Insert("HideBulkEmailCommands"                             , False);
	
	PrintSettings = New Structure;
	PrintSettings.Insert("TopMargin", 10);
	PrintSettings.Insert("LeftMargin", 10);
	PrintSettings.Insert("BottomMargin", 10);
	PrintSettings.Insert("RightMargin", 10);
	PrintSettings.Insert("PageOrientation", PageOrientation.Portrait);
	PrintSettings.Insert("FitToPage", True);
	PrintSettings.Insert("PrintScale", Undefined);
	
	Settings.Insert("Print", PrintSettings);
	
	Events = New Structure;
	Events.Insert("OnCreateAtServer", False);
	Events.Insert("BeforeImportSettingsToComposer", False);
	Events.Insert("BeforeLoadVariantAtServer", False);
	Events.Insert("OnLoadVariantAtServer", False);
	Events.Insert("OnLoadUserSettingsAtServer", False);
	Events.Insert("BeforeFillQuickSettingsBar", False);
	Events.Insert("AfterQuickSettingsBarFilled", False);
	Events.Insert("OnDefineSelectionParameters", False);
	Events.Insert("OnDefineUsedTables", False);
	Events.Insert("AddMetadataObjectsConnections", False);
	
	Settings.Insert("Events", Events);
	
	Return Settings;
EndFunction

#EndRegion

#Region Internal

// It finds a parameter in the composition settings by its name.
//   If user setting is not found (for example, if the parameter is not output in user settings), it 
//   searches the parameter value in option settings.
//   
//
// Parameters:
//   DCSettings - DataCompositionSettings, Undefined -
//       Report option settings where the second iteration of value search will be executed.
//   DCUserSettings - DataCompositionUserSettings, Undefined -
//       User settings where the first iteration of value search will be executed.
//   ParameterName - String - a parameter name. It must meet the requirements of generating variable names.
//
// Returns:
//   Structure - found parameter values.
//       Key - a parameter name;
//       Value - a parameter value. Undefined if a parameter is not found.
//
Function FindParameter(DCSettings, DCUserSettings, ParameterName) Export
	Return FindParameters(DCSettings, DCUserSettings, ParameterName)[ParameterName];
EndFunction

// It finds a common setting by a user setting ID.
//
// Parameters:
//   Settings - DataCompositionSettings - collections of settings.
//   UserSettingID - String -
//
Function GetObjectByUserID(Settings, UserSettingID, Hierarchy = Undefined) Export
	If Hierarchy <> Undefined Then
		Hierarchy.Add(Settings);
	EndIf;
	
	SettingType = TypeOf(Settings);
	
	If SettingType <> Type("DataCompositionSettings") Then
		
		If Settings.UserSettingID = UserSettingID Then
			
			Return Settings;
			
		ElsIf SettingType = Type("DataCompositionNestedObjectSettings") Then
			
			Return GetObjectByUserID(Settings.Settings, UserSettingID, Hierarchy);
			
		ElsIf SettingType = Type("DataCompositionTableStructureItemCollection")
			OR SettingType = Type("DataCompositionChartStructureItemCollection")
			OR SettingType = Type("DataCompositionSettingStructureItemCollection") Then
			
			For Each NestedItem In Settings Do
				SearchResult = GetObjectByUserID(NestedItem, UserSettingID, Hierarchy);
				If SearchResult <> Undefined Then
					Return SearchResult;
				EndIf;
			EndDo;
			
			If Hierarchy <> Undefined Then
				Hierarchy.Delete(Hierarchy.UBound());
			EndIf;
			
			Return Undefined;
			
		EndIf;
		
	EndIf;
	
	If Settings.Selection.UserSettingID = UserSettingID Then
		Return Settings.Selection;
	ElsIf Settings.ConditionalAppearance.UserSettingID = UserSettingID Then
		Return Settings.ConditionalAppearance;
	EndIf;
	
	If SettingType <> Type("DataCompositionTable") AND SettingType <> Type("DataCompositionChart") Then
		If Settings.Filter.UserSettingID = UserSettingID Then
			Return Settings.Filter;
		ElsIf Settings.Order.UserSettingID = UserSettingID Then
			Return Settings.Order;
		EndIf;
	EndIf;
	
	If SettingType = Type("DataCompositionSettings") Then
		SearchResult = FindSettingItem(Settings.DataParameters, UserSettingID);
		If SearchResult <> Undefined Then
			Return SearchResult;
		EndIf;
	EndIf;
	
	If SettingType <> Type("DataCompositionTable") AND SettingType <> Type("DataCompositionChart") Then
		SearchResult = FindSettingItem(Settings.Filter, UserSettingID);
		If SearchResult <> Undefined Then
			Return SearchResult;
		EndIf;
	EndIf;
	
	SearchResult = FindSettingItem(Settings.ConditionalAppearance, UserSettingID);
	If SearchResult <> Undefined Then
		Return SearchResult;
	EndIf;
	
	If SettingType = Type("DataCompositionTable") Then
		
		SearchResult = GetObjectByUserID(Settings.Rows, UserSettingID, Hierarchy);
		If SearchResult <> Undefined Then
			Return SearchResult;
		EndIf;
		
		SearchResult = GetObjectByUserID(Settings.Columns, UserSettingID, Hierarchy);
		If SearchResult <> Undefined Then
			Return SearchResult;
		EndIf;
		
	ElsIf SettingType = Type("DataCompositionChart") Then
		
		SearchResult = GetObjectByUserID(Settings.Points, UserSettingID, Hierarchy);
		If SearchResult <> Undefined Then
			Return SearchResult;
		EndIf;
		
		SearchResult = GetObjectByUserID(Settings.Series, UserSettingID, Hierarchy);
		If SearchResult <> Undefined Then
			Return SearchResult;
		EndIf;
		
	Else
		
		SearchResult = GetObjectByUserID(Settings.Structure, UserSettingID, Hierarchy);
		If SearchResult <> Undefined Then
			Return SearchResult;
		EndIf;
		
	EndIf;
	
	If Hierarchy <> Undefined Then
		Hierarchy.Delete(Hierarchy.UBound());
	EndIf;
	
	Return Undefined;
	
EndFunction

// Finds a user setting by its ID.
//
// Parameters:
//   DCUserSettings - DataCompositionUserSettings - Collection of user settings.
//   ID - String - an ID of the setting that you need to find.
//
// Returns:
//   Undefined - when setting is not found.
//   DataCompositionFilterItem, DataCompositionSettingsParameterValue and other types of items from 
//     DataCompositionUserSettingsItemCollection - a user setting.
//
Function FindUserSetting(DCUserSettings, ID) Export
	For Each UserSetting In DCUserSettings.Items Do
		If UserSetting.UserSettingID = ID Then
			Return UserSetting;
		EndIf;
	EndDo;
	
	Return Undefined;
EndFunction

// Finds an available setting for a filter or a parameter.
//
// Parameters:
//   DCSettings - DataCompositionSettings - Collections of settings.
//   DCItem - DataCompositionFilterItem, DataCompositionSettingsParameterValue,
//       DataCompositionNestedObjectSettings - setting item value.
//
// Returns:
//   DataCompositionAvailableField, DataCompositionAvailableParameter,
//       DataCompositionAvailableSettingsObject - found available setting.
//   Undefined - if an available setting is not found.
//
Function FindAvailableSetting(DCSettings, DCItem) Export
	Type = TypeOf(DCItem);
	If Type = Type("DataCompositionFilterItem") Then
		Return FindAvailableDCField(DCSettings, DCItem.LeftValue);
	ElsIf Type = Type("DataCompositionSettingsParameterValue") Then
		Return FindAvailableDCParameter(DCSettings, DCItem.Parameter);
	ElsIf Type = Type("DataCompositionNestedObjectSettings") Then
		Return DCSettings.AvailableObjects.Items.Find(DCItem.ObjectID);
	EndIf;
	
	Return Undefined;
EndFunction

// Finds an available setting by its ID.
//   If user setting is not found (for example, if the parameter is not output in user settings), it 
//   receives a common parameter setting.
//   
//
// Parameters:
//   DCSettingsComposer - DataCompositionSettingsComposer - settings composer.
//   ParameterName          - String - a parameter name.
//
// Returns:
//   DataCompositionSettingsParameterValue - a user setting of the parameter.
//   Undefined - if a parameter is not found.
//
Function GetParameter(DCSettingsComposer, ParameterName) Export
	DCParameter = New DataCompositionParameter(ParameterName);
	
	For Each UserSetting In DCSettingsComposer.UserSettings.Items Do
		If TypeOf(UserSetting) = Type("DataCompositionSettingsParameterValue")
			AND UserSetting.Parameter = DCParameter Then
			Return UserSetting;
		EndIf;
	EndDo;
	
	Return DCSettingsComposer.Settings.DataParameters.FindParameterValue(DCParameter);
EndFunction

// Finds parameters and filters by values.
//
// Parameters:
//   DCSettingsComposer - DataCompositionSettingsComposer - settings composer.
//   Filter              - Structure - search criteria.
//       * Usage - Boolean - setting usage.
//       * Value      - *      - setting value.
//   Result           - Array, Undefined - see return value.
//
// Returns:
//   Array - found user settings.
//
Function FindSettings(DCSettingsCollection, Filter, Result = Undefined) Export
	If Result = Undefined Then
		Result = New Array;
	EndIf;
	
	For Each DCSetting In DCSettingsCollection Do
		If TypeOf(DCSetting) = Type("DataCompositionFilterItem") 
			AND DCSetting.Use = Filter.Use
			AND DCSetting.RightValue = Filter.Value Then
			Result.Add(DCSetting);
		ElsIf TypeOf(DCSetting) = Type("DataCompositionSettingsParameterValue") 
			AND DCSetting.Use = Filter.Use
			AND DCSetting.Value = Filter.Value Then
			Result.Add(DCSetting);
		ElsIf TypeOf(DCSetting) = Type("DataCompositionFilter")
			Or TypeOf(DCSetting) = Type("DataCompositionFilterItemGroup") Then
			FindSettings(DCSetting.Items, Filter, Result);
		EndIf;
	EndDo;
	
	Return Result;
EndFunction

// The function returns the period type.
Function GetPeriodType(BeginOfPeriod, EndOfPeriod, AvailablePeriods = Undefined) Export
	
	PeriodType = Undefined;
	If BeginOfPeriod = BegOfDay(BeginOfPeriod)
		AND EndOfPeriod = EndOfDay(EndOfPeriod) Then
		
		DifferenceOfDays = (EndOfPeriod - BeginOfPeriod + 1) / (60*60*24);
		If DifferenceOfDays = 1 Then
			
			PeriodType = PredefinedValue("Enum.AvailableReportPeriods.Day");
			
		ElsIf DifferenceOfDays = 7 Then
			
			If BeginOfPeriod = BegOfWeek(BeginOfPeriod) Then
				PeriodType = PredefinedValue("Enum.AvailableReportPeriods.Week");
			EndIf;
			
		ElsIf DifferenceOfDays <= 11 Then
			
			If (Day(BeginOfPeriod) = 1 AND Day(EndOfPeriod) = 10)
				OR (Day(BeginOfPeriod) = 11 AND Day(EndOfPeriod) = 20)
				OR (Day(BeginOfPeriod) = 21 AND EndOfPeriod = EndOfMonth(BeginOfPeriod)) Then
				PeriodType = PredefinedValue("Enum.AvailableReportPeriods.TenDays");
			EndIf;
			
		ElsIf DifferenceOfDays <= 31 Then
			
			If BeginOfPeriod = BegOfMonth(BeginOfPeriod) AND EndOfPeriod = EndOfMonth(BeginOfPeriod) Then
				PeriodType = PredefinedValue("Enum.AvailableReportPeriods.Month");
			EndIf;
			
		ElsIf DifferenceOfDays <= 92 Then
			
			If BeginOfPeriod = BegOfQuarter(BeginOfPeriod) AND EndOfPeriod = EndOfQuarter(BeginOfPeriod) Then
				PeriodType = PredefinedValue("Enum.AvailableReportPeriods.Quarter");
			EndIf;
			
		ElsIf DifferenceOfDays <= 190 Then
			
			If Month(BeginOfPeriod) + 5 = Month(EndOfPeriod)
				AND BeginOfPeriod = BegOfMonth(BeginOfPeriod)
				AND EndOfPeriod = EndOfMonth(EndOfPeriod)
				AND (BeginOfPeriod = BegOfYear(BeginOfPeriod) OR EndOfPeriod = EndOfYear(BeginOfPeriod)) Then
				PeriodType = PredefinedValue("Enum.AvailableReportPeriods.HalfYear");
			EndIf;
			
		ElsIf DifferenceOfDays <= 366 Then
			
			If BeginOfPeriod = BegOfYear(BeginOfPeriod) AND EndOfPeriod = EndOfYear(BeginOfPeriod) Then
				PeriodType = PredefinedValue("Enum.AvailableReportPeriods.Year");
			EndIf;
			
		EndIf;
	EndIf;
	
	If PeriodType = Undefined Then
		PeriodType = PredefinedValue("Enum.AvailableReportPeriods.Custom");
	EndIf;
	
	If AvailablePeriods <> Undefined AND AvailablePeriods.FindByValue(PeriodType) = Undefined Then
		PeriodType = AvailablePeriods[0].Value;
	EndIf;
	
	Return PeriodType;
	
EndFunction

// Finds parameters and filters by values.
//
// Parameters:
//   Settings - DataCompositionUserSettings, Array - settings, whose items must be selected 
//               according to certain criteria.
//   Filter               - Structure - search criteria.
//       * Usage - Boolean - setting usage.
//       * Value      - *      - a setting value.
//   SettingsItems    - Undefined, DataCompositionUserSettingsItemCollection,
//                         DataCompositionFilterItemCollection - items of settings compared with the 
//                         criteria and placed in the result when the criteria are met.
//                         
//   Result           - Array, Undefined - see the return value.
//
// Returns:
//   Array - found user settings.
//
Function SettingsItemsFiltered(Settings, Filter, SettingsItems = Undefined, Result = Undefined) Export
	IsUserSettings = (TypeOf(Settings) = Type("DataCompositionUserSettings"));
	
	If SettingsItems = Undefined Then 
		SettingsItems = ?(IsUserSettings, Settings.Items, Settings);
	EndIf;
	
	If Result = Undefined Then
		Result = New Array;
	EndIf;
	
	For Each Item In SettingsItems Do
		ItemToAnalyse = Undefined;
		
		If IsUserSettings Then 
			ItemToAnalyse = Settings.Items.Find(Item.UserSettingID);
		EndIf;
		
		If ItemToAnalyse = Undefined Then 
			ItemToAnalyse = Item;
		EndIf;
		
		If TypeOf(ItemToAnalyse) = Type("DataCompositionFilterItem") 
			AND ItemToAnalyse.Use = Filter.Use
			AND ItemToAnalyse.RightValue = Filter.Value Then
			
			Result.Add(ItemToAnalyse);
			
		ElsIf TypeOf(ItemToAnalyse) = Type("DataCompositionSettingsParameterValue") 
			AND ItemToAnalyse.Use = Filter.Use
			AND ItemToAnalyse.Value = Filter.Value Then
			
			Result.Add(ItemToAnalyse);
			
		ElsIf TypeOf(ItemToAnalyse) = Type("DataCompositionFilter")
			Or TypeOf(ItemToAnalyse) = Type("DataCompositionFilterItemGroup") Then
			
			If ValueIsFilled(ItemToAnalyse.UserSettingID) Then 
				
				FoundItems = Settings.GetMainSettingsByUserSettingID(
					ItemToAnalyse.UserSettingID); // DataCompositionFilter, DataCompositionFilterItemsGroup
				
				If FoundItems.Count() > 0 Then
					CurrentSettingsItems = FoundItems.Get(0); // DataCompositionFilter, DataCompositionFilterItemsGroup
					SettingsItemsFiltered(Settings, Filter, CurrentSettingsItems.Items, Result);
				EndIf;
			EndIf;
		EndIf;
	EndDo;
	
	Return Result;
EndFunction

Function SettingItemIndexByPath(Val Path, ItemProperty = Undefined) Export 
	AvailableProperties = StrSplit("Use, Value, List", ", ", False);
	For Each ItemProperty In AvailableProperties Do 
		If StrEndsWith(Path, ItemProperty) Then 
			Break;
		EndIf;
	EndDo;
	
	IndexDetails = New TypeDescription("Number");
	
	ItemIndex = StrReplace(Path, "SettingsComposerUserSettingsItem", "");
	ItemIndex = StrReplace(ItemIndex, ItemProperty, "");
	
	Return IndexDetails.AdjustValue(ItemIndex);
EndFunction

#EndRegion

#Region Private

// Finds parameters in the composition settings by its name.
//   If a parameter is not found in user settings, it is searched in option settings.
//   
//
// Parameters:
//   DCSettings - DataCompositionSettings, Undefined -
//       Report option settings where the second iteration of value search will be executed.
//   DCUserSettings - DataCompositionUserSettings, Undefined -
//       User settings where the first iteration of value search will be executed.
//   ParameterNames - String - parameter names separated with commas.
//       Every parameter name must meet the requirements of variable name formation.
//
// Returns:
//   Structure - found parameter values.
//       Key - a parameter name;
//       Value - the found parameter. Undefined if a parameter is not found.
//
Function FindParameters(DCSettings, DCUserSettings, ParametersNames)
	Result = New Structure;
	RequiredParameters = New Map;
	NamesArray = StrSplit(ParametersNames, ",", False);
	Count = 0;
	For Each ParameterName In NamesArray Do
		RequiredParameters.Insert(TrimAll(ParameterName), True);
		Count = Count + 1;
	EndDo;
	
	If DCUserSettings <> Undefined Then
		For Each DCItem In DCUserSettings.Items Do
			If TypeOf(DCItem) = Type("DataCompositionSettingsParameterValue") Then
				ParameterName = String(DCItem.Parameter);
				If RequiredParameters[ParameterName] = True Then
					Result.Insert(ParameterName, DCItem);
					RequiredParameters.Delete(ParameterName);
					Count = Count - 1;
					If Count = 0 Then
						Break;
					EndIf;
				EndIf;
			EndIf;
		EndDo;
	EndIf;
	
	If Count > 0 Then
		For Each KeyAndValue In RequiredParameters Do
			If DCSettings <> Undefined Then
				DCItem = DCSettings.DataParameters.Items.Find(KeyAndValue.Key);
			Else
				DCItem = Undefined;
			EndIf;
			Result.Insert(KeyAndValue.Key, DCItem);
		EndDo;
	EndIf;
	
	Return Result;
EndFunction

// Finds an available data composition field setting.
//
// Parameters:
//   DCSettings - DataCompositionSettings - Collections of settings.
//   Field - String, DataCompositionField - a field name.
//
// Returns:
//   Undefined - When the available field setting is not found.
//   DataCompositionAvailableField - an available setting for a field.
//
Function FindAvailableDCField(DCSettings, DCField)
	If DCField = Undefined Then
		Return Undefined;
	EndIf;
	
	AvailableSetting = DCSettings.FilterAvailableFields.FindField(DCField);
	If AvailableSetting <> Undefined Then
		Return AvailableSetting;
	EndIf;
	
	StructuresArray = New Array;
	StructuresArray.Add(DCSettings.Structure);
	While StructuresArray.Count() > 0 Do
		
		DCStructure = StructuresArray[0];
		StructuresArray.Delete(0);
		
		For Each DCStructureItem In DCStructure Do
			
			If TypeOf(DCStructureItem) = Type("DataCompositionNestedObjectSettings") Then
				
				AvailableSetting = DCStructureItem.Settings.FilterAvailableFields.FindField(DCField);
				If AvailableSetting <> Undefined Then
					Return AvailableSetting;
				EndIf;
				
				StructuresArray.Add(DCStructureItem.Settings.Structure);
				
			ElsIf TypeOf(DCStructureItem) = Type("DataCompositionGroup") Then
				
				AvailableSetting = DCStructureItem.Filter.FilterAvailableFields.FindField(DCField);
				If AvailableSetting <> Undefined Then
					Return AvailableSetting;
				EndIf;
				
				StructuresArray.Add(DCStructureItem.Structure);
				
			EndIf;
			
		EndDo;
		
	EndDo;
	
	Return Undefined;
EndFunction

// Finds an available data composition parameter setting.
//
// Parameters:
//   DCSettings - DataCompositionSettings - Collections of settings.
//   DCParameter - DataCompositionParameter - a parameter name.
//
// Returns:
//   AvailableDataCompositionParameter, Undefined - available setting for a parameter.
//
Function FindAvailableDCParameter(DCSettings, DCParameter)
	If DCParameter = Undefined Then
		Return Undefined;
	EndIf;
	
	If DCSettings.DataParameters.AvailableParameters <> Undefined Then
		// Settings that own the data parameters are connected to the source of the available settings.
		AvailableSetting = DCSettings.DataParameters.AvailableParameters.FindParameter(DCParameter);
		If AvailableSetting <> Undefined Then
			Return AvailableSetting;
		EndIf;
	EndIf;
	
	StructuresArray = New Array;
	StructuresArray.Add(DCSettings.Structure);
	While StructuresArray.Count() > 0 Do
		
		DCStructure = StructuresArray[0];
		StructuresArray.Delete(0);
		
		For Each DCStructureItem In DCStructure Do
			
			If TypeOf(DCStructureItem) = Type("DataCompositionNestedObjectSettings") Then
				
				If DCStructureItem.Settings.DataParameters.AvailableParameters <> Undefined Then
					// Settings that own the data parameters are connected to the source of the available settings.
					AvailableSetting = DCStructureItem.Settings.DataParameters.AvailableParameters.FindParameter(DCParameter);
					If AvailableSetting <> Undefined Then
						Return AvailableSetting;
					EndIf;
				EndIf;
				
				StructuresArray.Add(DCStructureItem.Settings.Structure);
				
			ElsIf TypeOf(DCStructureItem) = Type("DataCompositionGroup") Then
				
				StructuresArray.Add(DCStructureItem.Structure);
				
			EndIf;
			
		EndDo;
		
	EndDo;
	
	Return Undefined;
EndFunction

// Adds the selected data composition field.
//
// Parameters:
//   Where - DataCompositionSettingsComposer, DataCompositionSettings, DataCompositionSelectedFields -
//       A collection, where the selected field has to be added.
//   DCNameOrField - String, DataCompositionField - a field name.
//   Title    - String - Optional. Field presentation.
//
// Returns:
//   DataCompositionSelectedField - an added selected field.
//
Function AddSelectedField(Destination, DCNameOrField, Header = "") Export
	
	If TypeOf(Destination) = Type("DataCompositionSettingsComposer") Then
		SelectedDCFields = Destination.Settings.Selection;
	ElsIf TypeOf(Destination) = Type("DataCompositionSettings") Then
		SelectedDCFields = Destination.Selection;
	Else
		SelectedDCFields = Destination;
	EndIf;
	
	If TypeOf(DCNameOrField) = Type("String") Then
		DCField = New DataCompositionField(DCNameOrField);
	Else
		DCField = DCNameOrField;
	EndIf;
	
	SelectedDCField = SelectedDCFields.Items.Add(Type("DataCompositionSelectedField"));
	SelectedDCField.Field = DCField;
	If Header <> "" Then
		SelectedDCField.Title = Header;
	EndIf;
	
	Return SelectedDCField;
	
EndFunction

// Casts value of the FoldersAndItemsUse type to the FoldersAndItems type.
//  Returns the Auto value for other types.
//
Function CastValueToGroupsAndItemsType(SourceValue, DefaultValue = Undefined) Export
	Type = TypeOf(SourceValue);
	If Type = Type("FoldersAndItems") Then
		Return SourceValue;
	ElsIf Type = Type("FoldersAndItemsUse") Then
		If SourceValue = FoldersAndItemsUse.Items Then
			Return FoldersAndItems.Items;
		ElsIf SourceValue = FoldersAndItemsUse.FoldersAndItems Then
			Return FoldersAndItems.FoldersAndItems;
		ElsIf SourceValue = FoldersAndItemsUse.Folders Then
			Return FoldersAndItems.Folders;
		EndIf;
	ElsIf Type = Type("DataCompositionComparisonType") Then
		If SourceValue = DataCompositionComparisonType.InList
			Or SourceValue = DataCompositionComparisonType.InListByHierarchy
			Or SourceValue = DataCompositionComparisonType.NotInList
			Or SourceValue = DataCompositionComparisonType.NotInListByHierarchy Then
			// The InListByHierarchy (In a group from the list) and NotInListByHierarchy (Not in a group from 
			// the list) comparison types must be considered "In a list or in groups" and "Not in a list and not in groups".
			// - It makes clear why they use "FoldersAndItems" instead of "Groups".
			Return FoldersAndItems.FoldersAndItems;
		ElsIf SourceValue = DataCompositionComparisonType.InHierarchy
			Or SourceValue = DataCompositionComparisonType.NotInHierarchy Then
			Return FoldersAndItems.Folders;
		EndIf;
	EndIf;
	Return ?(DefaultValue = Undefined, FoldersAndItems.Auto, DefaultValue);
EndFunction

// Casts value of the FoldersAndItems type to the FoldersAndItemsUse type.
//  For the Auto value and other types returns Undefined.
//
Function CastValueToGroupsAndItemsUsageType(SourceValue, DefaultValue = Undefined) Export
	Type = TypeOf(SourceValue);
	If Type = Type("FoldersAndItems") Then
		If SourceValue = FoldersAndItems.Items Then
			Return FoldersAndItemsUse.Items;
		ElsIf SourceValue = FoldersAndItems.FoldersAndItems Then
			Return FoldersAndItemsUse.FoldersAndItems;
		ElsIf SourceValue = FoldersAndItems.Folders Then
			Return FoldersAndItemsUse.Folders;
		ElsIf TypeOf(SourceValue) = Type("FoldersAndItemsUse") Then
			Return SourceValue;
		EndIf;
	ElsIf Type = Type("FoldersAndItemsUse") Then
		Return SourceValue;
	ElsIf Type = Type("DataCompositionComparisonType") Then
		If SourceValue = DataCompositionComparisonType.InList
			Or SourceValue = DataCompositionComparisonType.InListByHierarchy
			Or SourceValue = DataCompositionComparisonType.NotInList
			Or SourceValue = DataCompositionComparisonType.NotInListByHierarchy Then
			// The InListByHierarchy (In a group from the list) and NotInListByHierarchy (Not in a group from 
			// the list) comparison types must be considered "In a list or in groups" and "Not in a list and not in groups".
			// - It makes clear why they use "FoldersAndItems" instead of "Groups".
			Return FoldersAndItemsUse.FoldersAndItems;
		ElsIf SourceValue = DataCompositionComparisonType.InHierarchy
			Or SourceValue = DataCompositionComparisonType.NotInHierarchy Then
			Return FoldersAndItemsUse.Folders;
		EndIf;
	EndIf;
	If DefaultValue <> Undefined Then
		Return CastValueToGroupsAndItemsUsageType(DefaultValue, Undefined);
	EndIf;
	Return Undefined;
EndFunction

// Defines a full path to data composition item.
//
// Parameters:
//   DCSettings - DataCompositionSettings - Root settings node that is used as a start for a full path.
//   DCItem - Arbitrary - a setting node, to which a full path is built.
//
// Returns:
//   String - full path to an item. It can be used in the  FindItemByFullPath() function.
//   Undefined - if cannot build a full path.
//
Function FullPathToItem(Val DCSettings, Val DCItem) Export
	Result = New Array;
	DCParent = DCItem;
	While DCParent <> Undefined AND DCParent <> DCSettings Do
		DCItem = DCParent;
		DCParent = DCParent.Parent;
		ParentType = TypeOf(DCParent);
		If ParentType = Type("DataCompositionTable") Then
			Index = DCParent.Rows.IndexOf(DCItem);
			If Index = -1 Then
				Index = DCParent.Columns.IndexOf(DCItem);
				CollectionName = "Columns";
			Else
				CollectionName = "Rows";
			EndIf;
		ElsIf ParentType = Type("DataCompositionChart") Then
			Index = DCParent.Series.IndexOf(DCItem);
			If Index = -1 Then
				Index = DCParent.Points.IndexOf(DCItem);
				CollectionName = "Points";
			Else
				CollectionName = "Series";
			EndIf;
		ElsIf ParentType = Type("DataCompositionNestedObjectSettings") Then
			CollectionName = "Settings";
			Index = Undefined;
		Else
			CollectionName = "Structure";
			Index = DCParent.Structure.IndexOf(DCItem);
		EndIf;
		If Index = -1 Then
			Return Undefined;
		EndIf;
		If Index <> Undefined Then
			Result.Insert(0, Index);
		EndIf;
		Result.Insert(0, CollectionName);
	EndDo;
	Return StrConcat(Result, "/");
EndFunction

// Finds a data composition item by the full path.
//
// Parameters:
//   DCSettings - DataCompositionSettings - Root settings node containing the required item.
//   FullPathToItem - String - full path to an item. It can be retrieved in the FullPathToItem() function.
//
// Returns:
//   DCItem - Arbitrary - Found settings node.
//
Function FindItemByFullPath(Val DCSettings, Val FullPathToItem) Export
	IndexArray = StrSplit(FullPathToItem, "/", False);
	DCItem = DCSettings;
	For Each Index In IndexArray Do
		If Index = "Rows" Then
			DCItem = DCItem.Rows;
		ElsIf Index = "Columns" Then
			DCItem = DCItem.Columns;
		ElsIf Index = "Series" Then
			DCItem = DCItem.Series;
		ElsIf Index = "Points" Then
			DCItem = DCItem.Points;
		ElsIf Index = "Structure" Then
			DCItem = DCItem.Structure;
		ElsIf Index = "Settings" Then
			DCItem = DCItem.Settings;
		Else
			DCItem = DCItem[Number(Index)];
		EndIf;
	EndDo;
	Return DCItem;
EndFunction

// Imports new settings to the composer without resetting user settings.
//
// Parameters:
//   DCSettingsComposer - DataCompositionSettingsComposer - the place to load settings.
//   DCSettings - DataCompositionSettings - Option settings to be loaded.
//   DCUserSettings - DataCompositionUserSettings, Undefined - Optional.
//       User settings to import. If it is not specified, user settings are not imported.
//
Function LoadSettings(DCSettingsComposer, DCSettings, DCUserSettings = Undefined) Export
	SettingsImported = (TypeOf(DCSettings) = Type("DataCompositionSettings") AND DCSettings <> DCSettingsComposer.Settings);
	If SettingsImported Then
		If TypeOf(DCUserSettings) <> Type("DataCompositionUserSettings") Then
			DCUserSettings = DCSettingsComposer.UserSettings;
		EndIf;
		DCSettingsComposer.LoadSettings(DCSettings);
	EndIf;
	If TypeOf(DCUserSettings) = Type("DataCompositionUserSettings")
		AND DCUserSettings <> DCSettingsComposer.UserSettings Then
		DCSettingsComposer.LoadUserSettings(DCUserSettings);
	EndIf;
	Return SettingsImported;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Local internal procedures and functions.

// Finds a common data composition setting by ID.
Function FindSettingItem(SettingItem, UserSettingID)
	// Searching an item with the specified value of the UserSettingID (USID) property.
	
	GroupsArray = New Array;
	GroupsArray.Add(SettingItem.Items);
	
	While GroupsArray.Count() > 0 Do
		
		ItemCollection = GroupsArray.Get(0);
		GroupsArray.Delete(0);
		
		For Each SubordinateItem In ItemCollection Do
			If TypeOf(SubordinateItem) = Type("DataCompositionSelectedFieldGroup") Then
				// It does not contain USID; The collection of nested items does not contain USID.
			ElsIf TypeOf(SubordinateItem) = Type("DataCompositionParameterValue") Then
				// It does not contain USID; The collection of nested items can contain USID.
				GroupsArray.Add(SubordinateItem.NestedParameterValues);
			ElsIf SubordinateItem.UserSettingID = UserSettingID Then
				// The required item is found.
				Return SubordinateItem;
			Else
				// It contains USID; The collection of nested items can contain USID.
				If TypeOf(SubordinateItem) = Type("DataCompositionFilterItemGroup") Then
					GroupsArray.Add(SubordinateItem.Items);
				ElsIf TypeOf(SubordinateItem) = Type("DataCompositionSettingsParameterValue") Then
					GroupsArray.Add(SubordinateItem.NestedParameterValues);
				EndIf;
			EndIf;
		EndDo;
		
	EndDo;
	
	Return Undefined;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// For preiodicity mechanism operations.

// Returns a date of period start.
Function BeginOfReportPeriod(PeriodType, PeriodDate) Export
	BeginOfPeriod = PeriodDate;
	
	If PeriodType = PredefinedValue("Enum.AvailableReportPeriods.Custom") Then
		// No action required
	ElsIf PeriodType = PredefinedValue("Enum.AvailableReportPeriods.Year") Then
		BeginOfPeriod = BegOfYear(PeriodDate);
	ElsIf PeriodType = PredefinedValue("Enum.AvailableReportPeriods.HalfYear") Then
		If Month(PeriodDate) >= 7 Then
			BeginOfPeriod = Date(Year(PeriodDate), 7, 1);
		Else
			BeginOfPeriod = Date(Year(PeriodDate), 1, 1);
		EndIf;
	ElsIf PeriodType = PredefinedValue("Enum.AvailableReportPeriods.Quarter") Then
		BeginOfPeriod = BegOfQuarter(PeriodDate);
	ElsIf PeriodType = PredefinedValue("Enum.AvailableReportPeriods.Month") Then
		BeginOfPeriod = BegOfMonth(PeriodDate);
	ElsIf PeriodType = PredefinedValue("Enum.AvailableReportPeriods.TenDays") Then
		If Day(PeriodDate) <= 10 Then
			BeginOfPeriod = Date(Year(PeriodDate), Month(PeriodDate), 1);
		ElsIf Day(PeriodDate) <= 20 Then
			BeginOfPeriod = Date(Year(PeriodDate), Month(PeriodDate), 11);
		Else
			BeginOfPeriod = Date(Year(PeriodDate), Month(PeriodDate), 21);
		EndIf;
	ElsIf PeriodType = PredefinedValue("Enum.AvailableReportPeriods.Week") Then
		BeginOfPeriod = BegOfWeek(PeriodDate);
	ElsIf PeriodType = PredefinedValue("Enum.AvailableReportPeriods.Day") Then
		BeginOfPeriod = BegOfDay(PeriodDate);
	EndIf;
	
	Return BeginOfPeriod;
	
EndFunction

// Returns a date of period end.
Function EndOfReportPeriod(PeriodType, PeriodDate) Export
	EndOfPeriod = PeriodDate;
	
	If PeriodType = PredefinedValue("Enum.AvailableReportPeriods.Custom") Then
		// No action required
	ElsIf PeriodType = PredefinedValue("Enum.AvailableReportPeriods.Year") Then
		EndOfPeriod = EndOfYear(PeriodDate);
	ElsIf PeriodType = PredefinedValue("Enum.AvailableReportPeriods.HalfYear") Then
		If Month(PeriodDate) >= 7 Then
			EndOfPeriod = EndOfYear(PeriodDate);
		Else
			EndOfPeriod = EndOfDay(Date(Year(PeriodDate), 6, 30));
		EndIf;
	ElsIf PeriodType = PredefinedValue("Enum.AvailableReportPeriods.Quarter") Then
		EndOfPeriod = EndOfQuarter(PeriodDate);
	ElsIf PeriodType = PredefinedValue("Enum.AvailableReportPeriods.Month") Then
		EndOfPeriod = EndOfMonth(PeriodDate);
	ElsIf PeriodType = PredefinedValue("Enum.AvailableReportPeriods.TenDays") Then
		If Day(PeriodDate) <= 10 Then
			EndOfPeriod = EndOfDay(Date(Year(PeriodDate), Month(PeriodDate), 10));
		ElsIf Day(PeriodDate) <= 20 Then
			EndOfPeriod = EndOfDay(Date(Year(PeriodDate), Month(PeriodDate), 20));
		Else
			EndOfPeriod = EndOfMonth(PeriodDate);
		EndIf;
	ElsIf PeriodType = PredefinedValue("Enum.AvailableReportPeriods.Week") Then
		EndOfPeriod = EndOfWeek(PeriodDate);
	ElsIf PeriodType = PredefinedValue("Enum.AvailableReportPeriods.Day") Then
		EndOfPeriod = EndOfDay(PeriodDate);
	EndIf;
	
	Return EndOfPeriod;
	
EndFunction

// The function returns the period type. Receives StandardPeriod unlike the GetPeriodType function.
Function GetStandardPeriodType(StandardPeriod, AvailablePeriods = Undefined) Export
	
	If StandardPeriod.Variant = StandardPeriodVariant.Custom Then
		
		Return GetPeriodType(StandardPeriod.StartDate, StandardPeriod.EndDate, AvailablePeriods);
		
	ElsIf StandardPeriod.Variant = StandardPeriodVariant.ThisYear
		Or StandardPeriod.Variant = StandardPeriodVariant.LastYear
		Or StandardPeriod.Variant = StandardPeriodVariant.NextYear
		Or StandardPeriod.Variant = StandardPeriodVariant.FromBeginningOfThisYear
		Or StandardPeriod.Variant = StandardPeriodVariant.TillEndOfThisYear
		Or StandardPeriod.Variant = StandardPeriodVariant.LastYearTillSameDate
		Or StandardPeriod.Variant = StandardPeriodVariant.NextYearTillSameDate Then
		
		Return PredefinedValue("Enum.AvailableReportPeriods.Year");
		
	ElsIf StandardPeriod.Variant = StandardPeriodVariant.ThisHalfYear
		Or StandardPeriod.Variant = StandardPeriodVariant.LastHalfYear
		Or StandardPeriod.Variant = StandardPeriodVariant.NextHalfYear
		Or StandardPeriod.Variant = StandardPeriodVariant.FromBeginningOfThisHalfYear
		Or StandardPeriod.Variant = StandardPeriodVariant.TillEndOfThisHalfYear
		Or StandardPeriod.Variant = StandardPeriodVariant.LastHalfYearTillSameDate
		Or StandardPeriod.Variant = StandardPeriodVariant.NextHalfYearTillSameDate Then
		
		Return PredefinedValue("Enum.AvailableReportPeriods.HalfYear");
		
	ElsIf StandardPeriod.Variant = StandardPeriodVariant.ThisQuarter
		Or StandardPeriod.Variant = StandardPeriodVariant.LastQuarter
		Or StandardPeriod.Variant = StandardPeriodVariant.NextQuarter
		Or StandardPeriod.Variant = StandardPeriodVariant.FromBeginningOfThisQuarter
		Or StandardPeriod.Variant = StandardPeriodVariant.TillEndOfThisQuarter
		Or StandardPeriod.Variant = StandardPeriodVariant.LastQuarterTillSameDate
		Or StandardPeriod.Variant = StandardPeriodVariant.NextQuarterTillSameDate Then
		
		Return PredefinedValue("Enum.AvailableReportPeriods.Quarter");
		
	ElsIf StandardPeriod.Variant = StandardPeriodVariant.ThisMonth
		Or StandardPeriod.Variant = StandardPeriodVariant.LastMonth
		Or StandardPeriod.Variant = StandardPeriodVariant.NextMonth
		Or StandardPeriod.Variant = StandardPeriodVariant.Month
		Or StandardPeriod.Variant = StandardPeriodVariant.FromBeginningOfThisMonth
		Or StandardPeriod.Variant = StandardPeriodVariant.TillEndOfThisMonth
		Or StandardPeriod.Variant = StandardPeriodVariant.LastMonthTillSameDate
		Or StandardPeriod.Variant = StandardPeriodVariant.NextMonthTillSameDate Then
		
		Return PredefinedValue("Enum.AvailableReportPeriods.Month");
		
	ElsIf StandardPeriod.Variant = StandardPeriodVariant.ThisTenDays
		Or StandardPeriod.Variant = StandardPeriodVariant.LastTenDays
		Or StandardPeriod.Variant = StandardPeriodVariant.NextTenDays
		Or StandardPeriod.Variant = StandardPeriodVariant.FromBeginningOfThisTenDays
		Or StandardPeriod.Variant = StandardPeriodVariant.TillEndOfThisTenDays
		Or StandardPeriod.Variant = StandardPeriodVariant.LastTenDaysTillSameDayNumber
		Or StandardPeriod.Variant = StandardPeriodVariant.NextTenDaysTillSameDayNumber Then
		
		Return PredefinedValue("Enum.AvailableReportPeriods.TenDays");
		
	ElsIf StandardPeriod.Variant = StandardPeriodVariant.ThisWeek
		Or StandardPeriod.Variant = StandardPeriodVariant.LastWeek
		Or StandardPeriod.Variant = StandardPeriodVariant.NextWeek
		Or StandardPeriod.Variant = StandardPeriodVariant.FromBeginningOfThisWeek
		Or StandardPeriod.Variant = StandardPeriodVariant.TillEndOfThisWeek
		Or StandardPeriod.Variant = StandardPeriodVariant.Last7Days
		Or StandardPeriod.Variant = StandardPeriodVariant.Next7Days
		Or StandardPeriod.Variant = StandardPeriodVariant.LastWeekTillSameWeekDay
		Or StandardPeriod.Variant = StandardPeriodVariant.NextWeekTillSameWeekDay Then
		
		Return PredefinedValue("Enum.AvailableReportPeriods.Week");
		
	ElsIf StandardPeriod.Variant = StandardPeriodVariant.Today
		Or StandardPeriod.Variant = StandardPeriodVariant.Yesterday
		Or StandardPeriod.Variant = StandardPeriodVariant.Tomorrow Then
		
		Return PredefinedValue("Enum.AvailableReportPeriods.Day");
		
	EndIf;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Unifying the report form and report setting form.

Function ConditionalAppearanceItemPresentation(DCItem, DCOptionSetting, State) Export
	AppearancePresentation = AppearancePresentation(DCItem.Appearance);
	If AppearancePresentation = "" Then
		AppearancePresentation = NStr("ru = 'Не оформлять'; en = 'Do not create'; pl = 'Nie twórz';es_ES = 'No crear';es_CO = 'No crear';tr = 'Oluşturma';it = 'Non creare';de = 'Nicht erstellen'");
	EndIf;
	InfoFromOptionIsAvailable = (DCOptionSetting <> Undefined AND DCOptionSetting <> DCItem);
	
	FieldsPresentation = FormattedFieldsPresentation(DCItem.Fields, State);
	If FieldsPresentation = "" AND InfoFromOptionIsAvailable Then
		FieldsPresentation = FormattedFieldsPresentation(DCOptionSetting.Fields, State);
	EndIf;
	If FieldsPresentation = "" Then
		FieldsPresentation = NStr("ru = 'Все поля'; en = 'All fields'; pl = 'Wszystkie pola';es_ES = 'Todos campos';es_CO = 'Todos campos';tr = 'Tüm alanlar';it = 'Tutti i campi';de = 'Alle Felder'");
	Else
		FieldsPresentation = NStr("ru = 'Поля:'; en = 'Fields:'; pl = 'Pola:';es_ES = 'Campos:';es_CO = 'Campos:';tr = 'Alanlar:';it = 'Campi:';de = 'Felder:'") + " " + FieldsPresentation;
	EndIf;
	
	Try
		DCItemFilter = DCItem.Filter;
		
		FilterPresentation = FilterPresentation(DCItemFilter, DCItemFilter.Items, State);
		If FilterPresentation = "" AND InfoFromOptionIsAvailable Then
			FilterPresentation = FilterPresentation(DCOptionSetting.Filter, DCOptionSetting.Filter.Items, State);
		EndIf;
		
	Except
		
		FilterPresentation = "";
		
	EndTry;
	
	If FilterPresentation = "" Then
		Separator = "";
	Else
		Separator = "; ";
		FilterPresentation = NStr("ru = 'Условие:'; en = 'Condition:'; pl = 'Opis warunki:';es_ES = 'Condición:';es_CO = 'Condición:';tr = 'Durum:';it = 'Condizione:';de = 'Beschreibung der Bedingungen:'") + " " + FilterPresentation;
	EndIf;
	
	Return AppearancePresentation + " (" + FieldsPresentation + Separator + FilterPresentation + ")";
EndFunction

Function AppearancePresentation(DCAppearance)
	Presentation = "";
	For Each DCItem In DCAppearance.Items Do
		If DCItem.Use Then
			AvailableDCParameter = DCAppearance.AvailableParameters.FindParameter(DCItem.Parameter);
			If AvailableDCParameter <> Undefined AND ValueIsFilled(AvailableDCParameter.Title) Then
				KeyPresentation = AvailableDCParameter.Title;
			Else
				KeyPresentation = String(DCItem.Parameter);
			EndIf;
			
			If TypeOf(DCItem.Value) = Type("Color") Then
				ValuePresentation = ColorPresentation(DCItem.Value);
			Else
				ValuePresentation = String(DCItem.Value);
			EndIf;
			
			Presentation = Presentation
				+ ?(Presentation = "", "", ", ")
				+ KeyPresentation
				+ ?(ValuePresentation = "", "", ": " + ValuePresentation);
		EndIf;
	EndDo;
	Return Presentation;
EndFunction

Function ColorPresentation(Color)
	If Color.Type = ColorType.StyleItem Then
		Presentation = String(Color);
		Presentation = Mid(Presentation, StrFind(Presentation, ":")+1);
		Presentation = NameToPresentation(Presentation);
	ElsIf Color.Type = ColorType.WebColor
		Or Color.Type = ColorType.WindowsColor Then
		Presentation = StrLeftBeforeChar(String(Color), " (");
	ElsIf Color.Type = ColorType.Absolute Then
		Presentation = String(Color);
		If Presentation = "0, 0, 0" Then
			Presentation = NStr("ru = 'Черный'; en = 'Black'; pl = 'Czarny';es_ES = 'Negro';es_CO = 'Negro';tr = 'Siyah';it = 'Nero';de = 'Schwarz'");
		ElsIf Presentation = "255, 255, 255" Then
			Presentation = NStr("ru = 'Белый'; en = 'White'; pl = 'Biały';es_ES = 'Blanco';es_CO = 'Blanco';tr = 'Beyaz';it = 'Bianchi';de = 'Weiß'");
		EndIf;
	ElsIf Color.Type = ColorType.AutoColor Then
		Presentation = NStr("ru = 'Авто'; en = 'Auto'; pl = 'Auto';es_ES = 'Auto';es_CO = 'Auto';tr = 'Oto';it = 'Auto';de = 'Auto'");
	Else
		Presentation = "";
	EndIf;
	Return Presentation;
EndFunction

Function NameToPresentation(Val InitialString) Export
	Result = "";
	IsFirstSymbol = True;
	For CharNumber = 1 To StrLen(InitialString) Do
		CharCode = CharCode(InitialString, CharNumber);
		Char = Char(CharCode);
		If IsFirstSymbol Then
			If Not IsBlankString(Char) Then
				Result = Result + Char;
				IsFirstSymbol = False;
			EndIf;
		Else
			If (CharCode >= 65 AND CharCode <= 90)
				Or (CharCode >= 1040 AND CharCode <= 1071) Then
				Char = " " + Lower(Char);
			ElsIf Char = "_" Then
				Char = " ";
			EndIf;
			Result = Result + Char;
		EndIf;
	EndDo;
	Return Result;
EndFunction

Function FormattedFieldsPresentation(FormattedDCFields, State)
	Presentation = "";
	
	Try
		FormattedDCFieldsItems = FormattedDCFields.Items;
	Except
		Return Presentation;
	EndTry;
	
	For Each FormattedDCField In FormattedDCFieldsItems Do
		If Not FormattedDCField.Use Then
			Continue;
		EndIf;
		
		AvailableDCField = FormattedDCFields.AppearanceFieldsAvailableFields.FindField(FormattedDCField.Field);
		If AvailableDCField = Undefined Then
			State = "DeletionMark";
			FieldPresentation = String(FormattedDCField.Field);
		Else
			If ValueIsFilled(AvailableDCField.Title) Then
				FieldPresentation = AvailableDCField.Title;
			Else
				FieldPresentation = String(FormattedDCField.Field);
			EndIf;
		EndIf;
		Presentation = Presentation + ?(Presentation = "", "", ", ") + FieldPresentation;
		
	EndDo;
	
	Return Presentation;
EndFunction

Function FilterPresentation(DCNode, DCRowSet, State)
	Presentation = "";
	
	For Each DCItem In DCRowSet Do
		If Not DCItem.Use Then
			Continue;
		EndIf;
		
		If TypeOf(DCItem) = Type("DataCompositionFilterItemGroup") Then
			
			GroupPresentation = String(DCItem.GroupType);
			NestedItemsPresentation = FilterPresentation(DCNode, DCItem.Items, State);
			If NestedItemsPresentation = "" Then
				Continue;
			EndIf;
			ItemPresentation = GroupPresentation + "(" + NestedItemsPresentation + ")";
			
		ElsIf TypeOf(DCItem) = Type("DataCompositionFilterItem") Then
			
			AvailableDCFilterField = DCNode.FilterAvailableFields.FindField(DCItem.LeftValue);
			If AvailableDCFilterField = Undefined Then
				State = "DeletionMark";
				FieldPresentation = String(DCItem.LeftValue);
			Else
				If ValueIsFilled(AvailableDCFilterField.Title) Then
					FieldPresentation = AvailableDCFilterField.Title;
				Else
					FieldPresentation = String(DCItem.LeftValue);
				EndIf;
			EndIf;
			
			ValuePresentation = String(DCItem.RightValue);
			
			If DCItem.ComparisonType = DataCompositionComparisonType.Equal Then
				ConditionPresentation = "=";
			ElsIf DCItem.ComparisonType = DataCompositionComparisonType.NotEqual Then
				ConditionPresentation = "<>";
			ElsIf DCItem.ComparisonType = DataCompositionComparisonType.Greater Then
				ConditionPresentation = ">";
			ElsIf DCItem.ComparisonType = DataCompositionComparisonType.GreaterOrEqual Then
				ConditionPresentation = ">=";
			ElsIf DCItem.ComparisonType = DataCompositionComparisonType.Less Then
				ConditionPresentation = "<";
			ElsIf DCItem.ComparisonType = DataCompositionComparisonType.LessOrEqual Then
				ConditionPresentation = "<=";
			
			ElsIf DCItem.ComparisonType = DataCompositionComparisonType.InHierarchy Then
				ConditionPresentation = NStr("ru = 'В группе'; en = 'In group'; pl = 'W grupie';es_ES = 'En grupo';es_CO = 'En grupo';tr = 'Grupta';it = 'In gruppo';de = 'In Gruppe'");
			ElsIf DCItem.ComparisonType = DataCompositionComparisonType.NotInHierarchy Then
				ConditionPresentation = NStr("ru = 'Не в группе'; en = 'Not in group'; pl = 'Nie w grupie';es_ES = 'No en grupo';es_CO = 'No en grupo';tr = 'Grupta değil';it = 'Non nel gruppo';de = 'Nicht in der Gruppe'");
			ElsIf DCItem.ComparisonType = DataCompositionComparisonType.InList Then
				ConditionPresentation = NStr("ru = 'В списке'; en = 'In list'; pl = 'Na liście';es_ES = 'En la lista';es_CO = 'En la lista';tr = 'Listede';it = 'In elenco';de = 'In der Liste'");
			ElsIf DCItem.ComparisonType = DataCompositionComparisonType.NotInList Then
				ConditionPresentation = NStr("ru = 'Не в списке'; en = 'Not in list'; pl = 'Nie na liście';es_ES = 'No en la lista';es_CO = 'No en la lista';tr = 'Listede değil';it = 'Non in elenco';de = 'Nicht in der Liste'");
			ElsIf DCItem.ComparisonType = DataCompositionComparisonType.InListByHierarchy Then
				ConditionPresentation = NStr("ru = 'В списке включая подчиненные'; en = 'In the list including subordinate objects'; pl = 'Na liście łącznie z podporządkowanymi';es_ES = 'En la lista que incluye una subordinada';es_CO = 'En la lista que incluye una subordinada';tr = 'Alt listeler dahil listede';it = 'Nell''elenco includendo oggetti subordinati';de = 'In Liste einschließlich untergeordnet'");
			ElsIf DCItem.ComparisonType = DataCompositionComparisonType.NotInListByHierarchy Then
				ConditionPresentation = NStr("ru = 'Не в списке включая подчиненные'; en = 'Not in the list including subordinate objects'; pl = 'Nie na liście, łącznie z podporządkowanymi';es_ES = 'No en la lista, que incluye la subordinada';es_CO = 'No en la lista, que incluye la subordinada';tr = 'Alt listeler dahil listede değil';it = 'Non in elenco includendo oggetti subordinati';de = 'Nicht in der Liste, einschließlich untergeordnet'");
			
			ElsIf DCItem.ComparisonType = DataCompositionComparisonType.Contains Then
				ConditionPresentation = NStr("ru = 'Содержит'; en = 'Contains'; pl = 'Zawiera';es_ES = 'Contiene';es_CO = 'Contiene';tr = 'Içerir';it = 'Contiene';de = 'Enthält'");
			ElsIf DCItem.ComparisonType = DataCompositionComparisonType.NotContains Then
				ConditionPresentation = NStr("ru = 'Не содержит'; en = 'Does not contain'; pl = 'Nie zawiera';es_ES = 'No contiene';es_CO = 'No contiene';tr = 'Içermez';it = 'Non contiene';de = 'Enthält nicht'");
			ElsIf DCItem.ComparisonType = DataCompositionComparisonType.Like Then
				ConditionPresentation = NStr("ru = 'Соответствует шаблону'; en = 'Matches the template'; pl = 'Odpowiada szablonowi';es_ES = 'Corresponde al modelo';es_CO = 'Corresponde al modelo';tr = 'Şablona uygun';it = 'Corrisponde il template';de = 'Entspricht der Vorlage'");
			ElsIf DCItem.ComparisonType = DataCompositionComparisonType.NotLike Then
				ConditionPresentation = NStr("ru = 'Не соответствует шаблону'; en = 'Does not correspond to the template'; pl = 'Nie odpowiada szablonowi';es_ES = 'No corresponde al modelo';es_CO = 'No corresponde al modelo';tr = 'Şablona uygun değil';it = 'Non corrisponde al template';de = 'Entspricht nicht der Vorlage'");
			ElsIf DCItem.ComparisonType = DataCompositionComparisonType.BeginsWith Then
				ConditionPresentation = NStr("ru = 'Начинается с'; en = 'Begins with'; pl = 'Zaczyna się na';es_ES = 'Empieza con';es_CO = 'Empieza con';tr = 'İle başlar';it = 'Comincia con';de = 'Beginnt mit'");
			ElsIf DCItem.ComparisonType = DataCompositionComparisonType.NotBeginsWith Then
				ConditionPresentation = NStr("ru = 'Не начинается с'; en = 'Does not begin with'; pl = 'Nie zaczyna się na';es_ES = 'No empieza con';es_CO = 'No empieza con';tr = 'İle başlamaz';it = 'Non comincia con';de = 'Beginnt nicht mit'");
			ElsIf DCItem.ComparisonType = DataCompositionComparisonType.Filled Then
				ConditionPresentation = NStr("ru = 'Заполнено'; en = 'Filled'; pl = 'Wypełnił';es_ES = 'Rellenado';es_CO = 'Rellenado';tr = 'Dolduruldu';it = 'Compilato';de = 'Ausgefüllt'");
				ValuePresentation = "";
			ElsIf DCItem.ComparisonType = DataCompositionComparisonType.NotFilled Then
				ConditionPresentation = NStr("ru = 'Не заполнено'; en = 'Blank'; pl = 'Niewypełniony';es_ES = 'Vacía';es_CO = 'Vacía';tr = 'Boş';it = 'Vuoto';de = 'Leer'");
				ValuePresentation = "";
			EndIf;
			
			ItemPresentation = TrimAll(FieldPresentation + " " + ConditionPresentation + " " + ValuePresentation);
			
		Else
			Continue;
		EndIf;
		
		Presentation = Presentation + ?(Presentation = "", "", ", ") + ItemPresentation;
		
	EndDo;
	
	Return Presentation;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Other methods

Function SettingTypeAsString(Type) Export
	If Type = Type("DataCompositionSettings") Then
		Return "Settings";
	ElsIf Type = Type("DataCompositionNestedObjectSettings") Then
		Return "NestedObjectSettings";
	
	ElsIf Type = Type("DataCompositionFilter") Then
		Return "Filter";
	ElsIf Type = Type("DataCompositionFilterItem") Then
		Return "FilterItem";
	ElsIf Type = Type("DataCompositionFilterItemGroup") Then
		Return "FilterItemsGroup";
	
	ElsIf Type = Type("DataCompositionSettingsParameterValue") Then
		Return "SettingsParameterValue";
	
	ElsIf Type = Type("DataCompositionGroup") Then
		Return "Group";
	ElsIf Type = Type("DataCompositionGroupFields") Then
		Return "GroupFields";
	ElsIf Type = Type("DataCompositionGroupFieldCollection") Then
		Return "GroupFieldsCollection";
	ElsIf Type = Type("DataCompositionGroupField") Then
		Return "GroupField";
	ElsIf Type = Type("DataCompositionAutoGroupField") Then
		Return "AutoGroupField";
	
	ElsIf Type = Type("DataCompositionSelectedFields") Then
		Return "SelectedFields";
	ElsIf Type = Type("DataCompositionSelectedField") Then
		Return "SelectedField";
	ElsIf Type = Type("DataCompositionSelectedFieldGroup") Then
		Return "SelectedFieldsGroup";
	ElsIf Type = Type("DataCompositionAutoSelectedField") Then
		Return "AutoSelectedField";
	
	ElsIf Type = Type("DataCompositionOrder") Then
		Return "Order";
	ElsIf Type = Type("DataCompositionOrderItem") Then
		Return "OrderingItem";
	ElsIf Type = Type("DataCompositionAutoOrderItem") Then
		Return "AutoOrderItem";
	
	ElsIf Type = Type("DataCompositionConditionalAppearance") Then
		Return "ConditionalAppearance";
	ElsIf Type = Type("DataCompositionConditionalAppearanceItem") Then
		Return "ConditionalAppearanceItem";
	
	ElsIf Type = Type("DataCompositionSettingStructure") Then
		Return "SettingsStructure";
	ElsIf Type = Type("DataCompositionSettingStructureItemCollection") Then
		Return "SettingsStructureItemCollection";
	
	ElsIf Type = Type("DataCompositionTable") Then
		Return "Table";
	ElsIf Type = Type("DataCompositionTableGroup") Then
		Return "TableGroup";
	ElsIf Type = Type("DataCompositionTableStructureItemCollection") Then
		Return "TableStructureItemCollection";
	
	ElsIf Type = Type("DataCompositionChart") Then
		Return "Chart";
	ElsIf Type = Type("DataCompositionChartGroup") Then
		Return "ChartGroup";
	ElsIf Type = Type("DataCompositionChartStructureItemCollection") Then
		Return "ChartStructureItemCollection";
	
	ElsIf Type = Type("DataCompositionDataParameterValues") Then
		Return "DataParametersValues";
	
	Else
		Return "";
	EndIf;
EndFunction

Function CopyRecursive(Val Node, Val WhatToCopy, Val WhereToPaste, Val Index, Map) Export
	ItemType = TypeOf(WhatToCopy);
	CopyingParameters = CopyingParameters(ItemType, WhereToPaste);
	
	If CopyingParameters.ItemTypeMustBeSpecified Then
		If Index = Undefined Then
			NewRow = WhereToPaste.Add(ItemType);
		Else
			NewRow = WhereToPaste.Insert(Index, ItemType);
		EndIf;
	Else
		If Index = Undefined Then
			NewRow = WhereToPaste.Add();
		Else
			NewRow = WhereToPaste.Insert(Index);
		EndIf;
	EndIf;
	
	FillPropertiesRecursively(Node, NewRow, WhatToCopy, Map, CopyingParameters);
	
	Return NewRow;
EndFunction

Function CopyingParameters(ItemType, Collection)
	Result = New Structure;
	Result.Insert("ItemTypeMustBeSpecified", False);
	Result.Insert("ExcludeProperties", Undefined);
	Result.Insert("HasSettings", False);
	Result.Insert("HasItems", False);
	Result.Insert("HasSelection", False);
	Result.Insert("HasFilter", False);
	Result.Insert("HasOutputParameters", False);
	Result.Insert("HasDataParameters", False);
	Result.Insert("HasUserFields", False);
	Result.Insert("HasGroupFields", False);
	Result.Insert("HasOrder", False);
	Result.Insert("HasStructure", False);
	Result.Insert("HasConditionalAppearance", False);
	Result.Insert("HasColumnsAndRows", False);
	Result.Insert("HasSeriesAndDots", False);
	Result.Insert("HasNestedParametersValues", False);
	Result.Insert("HasFieldsAndDecorations", False);
	
	If ItemType = Type("DataCompositionSelectedFieldGroup")
		Or ItemType = Type("DataCompositionFilterItemGroup") Then
		
		Result.ItemTypeMustBeSpecified = True;
		Result.ExcludeProperties = "Parent";
		Result.HasItems = True;
		
	ElsIf ItemType = Type("DataCompositionSelectedField")
		Or ItemType = Type("DataCompositionAutoSelectedField")
		Or ItemType = Type("DataCompositionFilterItem") Then
		
		Result.ExcludeProperties = "Parent";
		Result.ItemTypeMustBeSpecified = True;
		
	ElsIf ItemType = Type("DataCompositionParameterValue")
		Or ItemType = Type("DataCompositionSettingsParameterValue") Then
		
		Result.ExcludeProperties = "Parent";
		
	ElsIf ItemType = Type("DataCompositionGroupField")
		Or ItemType = Type("DataCompositionAutoGroupField")
		Or ItemType = Type("DataCompositionOrderItem")
		Or ItemType = Type("DataCompositionAutoOrderItem") Then
		
		Result.ItemTypeMustBeSpecified = True;
		
	ElsIf ItemType = Type("DataCompositionConditionalAppearanceItem") Then
		
		Result.HasFilter = True;
		Result.HasFieldsAndDecorations = True;
		
	ElsIf ItemType = Type("DataCompositionGroup")
		Or ItemType = Type("DataCompositionTableGroup")
		Or ItemType = Type("DataCompositionChartGroup")Then
		
		Result.ExcludeProperties = "Parent";
		CollectionType = TypeOf(Collection);
		If CollectionType = Type("DataCompositionSettingStructureItemCollection") Then
			Result.ItemTypeMustBeSpecified = True;
			ItemType = Type("DataCompositionGroup"); // Replacing type with the supported one.
		EndIf;
		
		Result.HasSelection = True;
		Result.HasFilter = True;
		Result.HasOutputParameters = True;
		Result.HasGroupFields = True;
		Result.HasOrder = True;
		Result.HasStructure = True;
		Result.HasConditionalAppearance = True;
		
	ElsIf ItemType = Type("DataCompositionTable") Then
		
		Result.ExcludeProperties = "Parent";
		Result.ItemTypeMustBeSpecified = True;
		
		Result.HasSelection = True;
		Result.HasColumnsAndRows = True;
		Result.HasOutputParameters = True;
		
	ElsIf ItemType = Type("DataCompositionChart") Then
		
		Result.ExcludeProperties = "Parent";
		Result.ItemTypeMustBeSpecified = True;
		
		Result.HasSelection = True;
		Result.HasSeriesAndDots = True;
		Result.HasOutputParameters = True;
		
	ElsIf ItemType = Type("DataCompositionNestedObjectSettings") Then
		
		Result.ExcludeProperties = "Parent";
		Result.ItemTypeMustBeSpecified = True;
		Result.HasSettings = True;
		
		Result.HasSelection = True;
		Result.HasFilter = True;
		Result.HasOutputParameters = True;
		Result.HasDataParameters = True;
		Result.HasUserFields = True;
		Result.HasOrder = True;
		Result.HasStructure = True;
		Result.HasConditionalAppearance = True;
		
	ElsIf ItemType <> Type("FormDataTreeItem") Then 
		
#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
		If ItemType = Type("ValueTreeRow") Then
			Return Result;
		EndIf;
#EndIf	
		
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Копирование элементов ""%1"" не поддерживается'; en = 'Copying of items ""%1"" is not supported.'; pl = 'Kopiowanie elementów ""%1"" nie jest obsługiwane.';es_ES = 'No se admite copiar los artículos ""%1"".';es_CO = 'No se admite copiar los artículos ""%1"".';tr = '""%1"" öğelerinin kopyalanması desteklenmiyor.';it = 'La copia degli elementi ""%1"" non è supportata';de = 'Kopieren von Elementen ""%1"" wird nicht unterstützt.'"), ItemType);
		
	EndIf;
	
	Return Result;
	
EndFunction

Function FillPropertiesRecursively(Node, WhatToFill, FillWithWhat, Map = Undefined, CopyingParameters = Undefined) Export
	If Map = Undefined Then
		Map = New Map;
	EndIf;
	If CopyingParameters = Undefined Then
		CopyingParameters = CopyingParameters(TypeOf(FillWithWhat), Undefined);
	EndIf;
	
	If CopyingParameters.ExcludeProperties <> "*" Then
		FillPropertyValues(WhatToFill, FillWithWhat, , CopyingParameters.ExcludeProperties);
	EndIf;
	
	IsDataTreeFormItem = TypeOf(FillWithWhat) = Type("FormDataTreeItem");
#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
	IsValueTree = TypeOf(FillWithWhat) = Type("ValueTreeRow");
#Else
	IsValueTree = False;
#EndIf	
	If IsDataTreeFormItem Or IsValueTree Then
		
		Map.Insert(FillWithWhat, WhatToFill);
		
		NestedItemsCollection = ?(IsDataTreeFormItem, FillWithWhat.GetItems(), FillWithWhat.Rows);
		If NestedItemsCollection.Count() > 0 Then
			NewNestedItemsCollection = ?(IsDataTreeFormItem, WhatToFill.GetItems(), WhatToFill.Rows);
			For Each SubordinateRow In NestedItemsCollection Do
				CopyRecursive(Node, SubordinateRow, NewNestedItemsCollection, Undefined, Map);
			EndDo;
		EndIf;
		
		Return WhatToFill;
	EndIf;
		
	OldID = Node.GetIDByObject(FillWithWhat);
	NewID = Node.GetIDByObject(WhatToFill);
	Map.Insert(OldID, NewID);
	
	If CopyingParameters.HasSettings Then
		WhatToFill.SetIdentifier(FillWithWhat.ObjectID);
		WhatToFill = WhatToFill.Settings;
		FillWithWhat = FillWithWhat.Settings;
	EndIf;
	
	If CopyingParameters.HasItems Then
		//   Items (DataCompositionSelectedFieldCollection,
		//       DataCompositionFilterItemCollection).
		NestedItemsCollection = FillWithWhat.Items;
		If NestedItemsCollection.Count() > 0 Then
			NewNestedItemsCollection = WhatToFill.Items;
			For Each SubordinateRow In NestedItemsCollection Do
				CopyRecursive(Node, SubordinateRow, NewNestedItemsCollection, Undefined, Map);
			EndDo;
		EndIf;
	EndIf;
	
	If CopyingParameters.HasSelection Then
		//   Choice (DataCompositionSelectedFields).
		FillPropertyValues(WhatToFill.Selection, FillWithWhat.Selection, , "SelectionAvailableFields, Items");
		//   Choice.Items (DataCompositionSelectedFieldCollection).
		NestedItemsCollection = FillWithWhat.Selection.Items;
		If NestedItemsCollection.Count() > 0 Then
			NewNestedItemsCollection = WhatToFill.Selection.Items;
			For Each SubordinateRow In NestedItemsCollection Do
				CopyRecursive(Node, SubordinateRow, NewNestedItemsCollection, Undefined, Map);
			EndDo;
		EndIf;
	EndIf;
	
	If CopyingParameters.HasFilter Then
		//   Filter (DataCompositionFilter).
		FillPropertyValues(WhatToFill.Filter, FillWithWhat.Filter, , "FilterAvailableFields, Items");
		//   Filter.Items (DataCompositionFilterItemCollection).
		NestedItemsCollection = FillWithWhat.Filter.Items;
		If NestedItemsCollection.Count() > 0 Then
			NewNestedItemsCollection = WhatToFill.Filter.Items;
			For Each SubordinateRow In NestedItemsCollection Do
				CopyRecursive(Node, SubordinateRow, NewNestedItemsCollection, Undefined, New Map);
			EndDo;
		EndIf;
	EndIf;
	
	If CopyingParameters.HasOutputParameters Then
		//   OutputParameters (DataCompositionOutputParameterValues,
		//       DataCompositionGroupOutputParameterValues,
		//       DataCompositionTableGroupOutputParameterValues,
		//       DataCompositionChartGroupOutputParameterValues,
		//       DataCompositionTableOutputParameterValues,
		//       DataCompositionChartOutputParameterValues).
		//   OutputParameters.Items (DataCompositionParameterValueCollection).
		NestedItemsCollection = FillWithWhat.OutputParameters.Items;
		If NestedItemsCollection.Count() > 0 Then
			NestedItemsNode = WhatToFill.OutputParameters;
			For Each SubordinateRow In NestedItemsCollection Do
				DCParameterValue = NestedItemsNode.FindParameterValue(SubordinateRow.Parameter);
				If DCParameterValue <> Undefined Then
					FillPropertyValues(DCParameterValue, SubordinateRow);
				EndIf;
			EndDo;
		EndIf;
	EndIf;
	
	If CopyingParameters.HasDataParameters Then
		//   DataParameters (DataCompositionDataParameterValues).
		//   DataParameters.Items (DataCompositionParameterValueCollection).
		NestedItemsCollection = FillWithWhat.DataParameters.Items;
		If NestedItemsCollection.Count() > 0 Then
			NestedItemsNode = WhatToFill.DataParameters;
			For Each SubordinateRow In NestedItemsCollection Do
				DCParameterValue = NestedItemsNode.FindParameterValue(SubordinateRow.Parameter);
				If DCParameterValue <> Undefined Then
					FillPropertyValues(DCParameterValue, SubordinateRow);
				EndIf;
			EndDo;
		EndIf;
	EndIf;
	
	If CopyingParameters.HasUserFields Then
		//   UserFields (DataCompositionUserFields).
		//   ПользовательскиеПоля.Items (DataCompositionUserFieldCollection).
		NestedItemsCollection = FillWithWhat.UserFields.Items;
		If NestedItemsCollection.Count() > 0 Then
			NewNestedItemsCollection = WhatToFill.UserFields.Items;
			For Each SubordinateRow In NestedItemsCollection Do
				CopyRecursive(Node, SubordinateRow, NewNestedItemsCollection, Undefined, Map);
			EndDo;
		EndIf;
	EndIf;
	
	If CopyingParameters.HasGroupFields Then
		//   GroupFields (DataCompositionGroupFields).
		//   GroupFields.Items (DataCompositionGroupFieldCollection).
		NestedItemsCollection = FillWithWhat.GroupFields.Items;
		If NestedItemsCollection.Count() > 0 Then
			NewNestedItemsCollection = WhatToFill.GroupFields.Items;
			For Each SubordinateRow In NestedItemsCollection Do
				CopyRecursive(Node, SubordinateRow, NewNestedItemsCollection, Undefined, New Map);
			EndDo;
		EndIf;
	EndIf;
	
	If CopyingParameters.HasOrder Then
		//   Order (DataCompositionOrder).
		FillPropertyValues(WhatToFill.Order, FillWithWhat.Order, , "OrderAvailableFields, Items");
		//   Order.Items (DataCompositionOrderItemCollection).
		NestedItemsCollection = FillWithWhat.Order.Items;
		If NestedItemsCollection.Count() > 0 Then
			NewNestedItemsCollection = WhatToFill.Order.Items;
			For Each SubordinateRow In NestedItemsCollection Do
				CopyRecursive(Node, SubordinateRow, NewNestedItemsCollection, Undefined, Map);
			EndDo;
		EndIf;
	EndIf;
	
	If CopyingParameters.HasStructure Then
		//   Structure (DataCompositionSettingStructureItemCollection,
		//       DataCompositionChartStructureItemCollection,
		//       DataCompositionTableStructureItemCollection).
		FillPropertyValues(WhatToFill.Structure, FillWithWhat.Structure);
		NestedItemsCollection = FillWithWhat.Structure;
		If NestedItemsCollection.Count() > 0 Then
			NewNestedItemsCollection = WhatToFill.Structure;
			For Each SubordinateRow In NestedItemsCollection Do
				CopyRecursive(Node, SubordinateRow, NewNestedItemsCollection, Undefined, Map);
			EndDo;
		EndIf;
	EndIf;
	
	If CopyingParameters.HasConditionalAppearance Then
		//   ConditionalAppearance (DataCompositionConditionalAppearance).
		FillPropertyValues(WhatToFill.ConditionalAppearance, FillWithWhat.ConditionalAppearance, , "FilterAvailableFields, FieldsAvailableFields, Items");
		//   ConditionalAppearance.Items (DataCompositionConditionalAppearanceItemCollection).
		NestedItemsCollection = FillWithWhat.ConditionalAppearance.Items;
		If NestedItemsCollection.Count() > 0 Then
			NewNestedItemsCollection = WhatToFill.ConditionalAppearance.Items;
			For Each SubordinateRow In NestedItemsCollection Do
				CopyRecursive(Node, SubordinateRow, NewNestedItemsCollection, Undefined, Map);
			EndDo;
		EndIf;
	EndIf;
	
	If CopyingParameters.HasColumnsAndRows Then
		//   Columns (DataCompositionTableStructureItemCollection).
		NestedItemsCollection = FillWithWhat.Columns;
		NewNestedItemsCollection = WhatToFill.Columns;
		OldID = Node.GetIDByObject(NestedItemsCollection);
		NewID = Node.GetIDByObject(NewNestedItemsCollection);
		Map.Insert(OldID, NewID);
		For Each SubordinateRow In NestedItemsCollection Do
			CopyRecursive(Node, SubordinateRow, NewNestedItemsCollection, Undefined, Map);
		EndDo;
		//   Rows (DataCompositionTableStructureItemCollection).
		NestedItemsCollection = FillWithWhat.Rows;
		NewNestedItemsCollection = WhatToFill.Rows;
		OldID = Node.GetIDByObject(NestedItemsCollection);
		NewID = Node.GetIDByObject(NewNestedItemsCollection);
		Map.Insert(OldID, NewID);
		For Each SubordinateRow In NestedItemsCollection Do
			CopyRecursive(Node, SubordinateRow, NewNestedItemsCollection, Undefined, Map);
		EndDo;
	EndIf;
	
	If CopyingParameters.HasSeriesAndDots Then
		//   Series (DataCompositionChartStructureItemCollection).
		NestedItemsCollection = FillWithWhat.Series;
		NewNestedItemsCollection = WhatToFill.Series;
		OldID = Node.GetIDByObject(NestedItemsCollection);
		NewID = Node.GetIDByObject(NewNestedItemsCollection);
		Map.Insert(OldID, NewID);
		For Each SubordinateRow In NestedItemsCollection Do
			CopyRecursive(Node, SubordinateRow, NewNestedItemsCollection, Undefined, Map);
		EndDo;
		//   Dots (DataCompositionChartStructureItemCollection).
		NestedItemsCollection = FillWithWhat.Points;
		NewNestedItemsCollection = WhatToFill.Points;
		OldID = Node.GetIDByObject(NestedItemsCollection);
		NewID = Node.GetIDByObject(NewNestedItemsCollection);
		Map.Insert(OldID, NewID);
		For Each SubordinateRow In NestedItemsCollection Do
			CopyRecursive(Node, SubordinateRow, NewNestedItemsCollection, Undefined, Map);
		EndDo;
	EndIf;
	
	If CopyingParameters.HasNestedParametersValues Then
		//   NestedParameterValues (DataCompositionParameterValueCollection).
		For Each SubordinateRow In FillWithWhat.NestedParameterValues Do
			CopyRecursive(Node, SubordinateRow, WhatToFill.NestedParameterValues, Undefined, Map);
		EndDo;
	EndIf;
	
	If CopyingParameters.HasFieldsAndDecorations Then
		For Each FormattedField In FillWithWhat.Fields.Items Do
			FillPropertyValues(WhatToFill.Fields.Items.Add(), FormattedField);
		EndDo;
		For Each Source In FillWithWhat.Appearance.Items Do
			Destination = WhatToFill.Appearance.FindParameterValue(Source.Parameter);
			If Destination <> Undefined Then
				FillPropertyValues(Destination, Source, , "Parent");
				For Each NestedSource In Source.NestedParameterValues Do
					NestedDestination = WhatToFill.Appearance.FindParameterValue(Source.Parameter);
					If NestedDestination <> Undefined Then
						FillPropertyValues(NestedDestination, NestedSource, , "Parent");
					EndIf;
				EndDo;
			EndIf;
		EndDo;
	EndIf;
		
	Return WhatToFill;
EndFunction

Function SpecifyItemTypeOnAddToCollection(CollectionType) Export
	If CollectionType = Type("DataCompositionTableStructureItemCollection")
		Or CollectionType = Type("DataCompositionChartStructureItemCollection")
		Or CollectionType = Type("DataCompositionConditionalAppearanceItemCollection") Then
		Return False;
	Else
		Return True;
	EndIf;
EndFunction

Function AddUniqueValueToList(ValueList, Value, Presentation, Usage) Export
	If Not ValueIsFilled(Value) AND Not ValueIsFilled(Presentation) Then
		Return Undefined;
	EndIf;
	ListItem = ValueList.FindByValue(Value);
	If ListItem = Undefined Then
		ListItem = ValueList.Add();
		ListItem.Value = Value;
	EndIf;
	If ValueIsFilled(Presentation) Then
		ListItem.Presentation = Presentation;
	ElsIf Not ValueIsFilled(ListItem.Presentation) Then
		ListItem.Presentation = String(Value);
	EndIf;
	If Usage AND Not ListItem.Check Then
		ListItem.Check = True;
	EndIf;
	Return ListItem;
EndFunction

Function ValuesByList(Values) Export
	If TypeOf(Values) = Type("ValueList") Then
		Return Values;
	Else
		ValueList = New ValueList;
		If TypeOf(Values) = Type("Array") Then
			ValueList.LoadValues(Values);
		ElsIf Values <> Undefined Then
			ValueList.Add(Values);
		EndIf;
		Return ValueList;
	EndIf;
EndFunction

Function TypesDetailsMatch(TypesDetails1, TypesDetails2)
	If TypesDetails1 = Undefined Or TypesDetails2 = Undefined Then
		Return False;
	EndIf;
	If TypesDetails1 = TypesDetails2 Or String(TypesDetails1) = String(TypesDetails2) Then
		Return True;
	EndIf;
	
	#If Server Then
		If Common.ValueToXMLString(TypesDetails1) = Common.ValueToXMLString(TypesDetails2) Then
			Return True;
		EndIf;
	#EndIf
	
	Return False;
EndFunction

Function AddToList(DestinationList, SourceList, CheckType = Undefined, AddNewItems = True) Export
	If DestinationList = Undefined Or SourceList = Undefined Then
		Return Undefined;
	EndIf;
	
	ReplaceExistingItems = True;
	ReplacePresentation = ReplaceExistingItems AND AddNewItems;
	
	Result = New Structure;
	Result.Insert("Total", 0);
	Result.Insert("Added", 0);
	Result.Insert("Updated", 0);
	Result.Insert("Skipped", 0);
	
	If CheckType = Undefined Then
		CheckType = Not TypesDetailsMatch(DestinationList.ValueType, SourceList.ValueType);
	EndIf;
	If CheckType Then
		DestinationTypesDetails = DestinationList.ValueType;
	EndIf;
	For Each SourceItem In SourceList Do
		Result.Total = Result.Total + 1;
		Value = SourceItem.Value;
		If CheckType AND Not DestinationTypesDetails.ContainsType(TypeOf(Value)) Then
			Result.Skipped = Result.Skipped + 1;
			Continue;
		EndIf;
		DestinationItem = DestinationList.FindByValue(Value);
		If DestinationItem = Undefined Then
			If AddNewItems Then
				Result.Added = Result.Added + 1;
				FillPropertyValues(DestinationList.Add(), SourceItem);
			Else
				Result.Skipped = Result.Skipped + 1;
			EndIf;
		Else
			If ReplaceExistingItems Then
				Result.Updated = Result.Updated + 1;
				FillPropertyValues(DestinationItem, SourceItem, , ?(ReplacePresentation, "", "Presentation"));
			Else
				Result.Skipped = Result.Skipped + 1;
			EndIf;
		EndIf;
	EndDo;
	Return Result;
EndFunction

Function ValueToArray(Value) Export
	If TypeOf(Value) = Type("Array") Then
		Return Value;
	Else
		Array = New Array;
		Array.Add(Value);
		Return Array;
	EndIf;
EndFunction

Function TypesAnalysis(SourceTypesDetails, CastToForm) Export
	Result = New Structure;
	Result.Insert("ContainsTypeType",        False);
	Result.Insert("ContainsDateType",       False);
	Result.Insert("ContainsBooleanType",     False);
	Result.Insert("ContainsStringType",     False);
	Result.Insert("ContainsNumberType",      False);
	Result.Insert("ContainsPeriodType",     False);
	Result.Insert("ContainsUUIDType",        False);
	Result.Insert("ContainsStorageType",  False);
	Result.Insert("ContainsObjectTypes", False);
	Result.Insert("ReducedLengthItem",     True);
	
	Result.Insert("TypesCount",            0);
	Result.Insert("PrimitiveTypesNumber", 0);
	Result.Insert("ObjectTypes", New Array);
	
	If CastToForm Then
		TypesToAdd = New Array;
		RemovedTypes = New Array;
		Result.Insert("OriginalTypesDetails", SourceTypesDetails);
		Result.Insert("TypesDetailsForForm", SourceTypesDetails);
	EndIf;
	
	If SourceTypesDetails = Undefined Then
		Return Result;
	EndIf;
	
	TypesArray = SourceTypesDetails.Types();
	For Each Type In TypesArray Do
		If Type = Type("DataCompositionField") Then
			If CastToForm Then
				RemovedTypes.Add(Type);
			EndIf;
			Continue;
		EndIf;
#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
		SettingMetadata = Metadata.FindByType(Type);
		If SettingMetadata <> Undefined AND Not Common.MetadataObjectAvailableByFunctionalOptions(SettingMetadata) Then
			If CastToForm Then
				RemovedTypes.Add(Type);
			EndIf;
			Continue;
		EndIf;
#EndIf
		
		Result.TypesCount = Result.TypesCount + 1;
		
		If Type = Type("Type") Then
			Result.ContainsTypeType = True;
		ElsIf Type = Type("Date") Then
			Result.ContainsDateType = True;
			Result.PrimitiveTypesNumber = Result.PrimitiveTypesNumber + 1;
		ElsIf Type = Type("Boolean") Then
			Result.ContainsBooleanType = True;
			Result.PrimitiveTypesNumber = Result.PrimitiveTypesNumber + 1;
		ElsIf Type = Type("Number") Then
			Result.ContainsNumberType = True;
			Result.PrimitiveTypesNumber = Result.PrimitiveTypesNumber + 1;
		ElsIf Type = Type("StandardPeriod") Then
			Result.ContainsPeriodType = True;
		ElsIf Type = Type("String") Then
			Result.ContainsStringType = True;
			Result.PrimitiveTypesNumber = Result.PrimitiveTypesNumber + 1;
			If SourceTypesDetails.StringQualifiers.Length = 0
				AND SourceTypesDetails.StringQualifiers.AllowedLength = AllowedLength.Variable Then
				Result.ReducedLengthItem = False;
			EndIf;
		ElsIf Type = Type("UUID") Then
			Result.ContainsUUIDType = True;
		ElsIf Type = Type("ValueStorage") Then
			Result.ContainsStorageType = True;
		Else
			Result.ContainsObjectTypes = True;
			Result.ObjectTypes.Add(Type);
		EndIf;
		
	EndDo;
	
	If CastToForm
		AND (TypesToAdd.Count() > 0 Or RemovedTypes.Count() > 0) Then
		Result.TypesDetailsForForm = New TypeDescription(SourceTypesDetails, TypesToAdd, RemovedTypes);
	EndIf;
	
	Return Result;
EndFunction

Function CastIDToName(ID) Export
	Return StrReplace(StrReplace(String(ID), "-", ""), ".", "_");
EndFunction

Function StrLeftBeforeChar(Row, Separator, Balance = Undefined)
	Position = StrFind(Row, Separator);
	If Position = 0 Then
		StringBeforeDot = Row;
		Balance = "";
	Else
		StringBeforeDot = Left(Row, Position - 1);
		Balance = Mid(Row, Position + 1);
	EndIf;
	Return StringBeforeDot;
EndFunction

Function ComparisonTypesSelectionList(TypesDetails) Export
	TypesInformation = TypesAnalysis(TypesDetails, False);
	
	List = New ValueList;
	
	If TypesInformation.ReducedLengthItem Then
		
		List.Add(DataCompositionComparisonType.Equal);
		List.Add(DataCompositionComparisonType.NotEqual);
		
		List.Add(DataCompositionComparisonType.InList);
		List.Add(DataCompositionComparisonType.NotInList);
		
		If TypesInformation.ContainsObjectTypes Then
			
			List.Add(DataCompositionComparisonType.InListByHierarchy); // NStr("en = 'In a list including subordinate objects'")
			List.Add(DataCompositionComparisonType.NotInListByHierarchy); // NStr("en = 'Not in a list including subordinate objects").
			
			List.Add(DataCompositionComparisonType.InHierarchy); // NStr("en = 'In a group'")
			List.Add(DataCompositionComparisonType.NotInHierarchy); // NStr("en = 'Not in a group'")
			
		EndIf;
		
		If TypesInformation.PrimitiveTypesNumber > 0 Then
			
			List.Add(DataCompositionComparisonType.Less);
			List.Add(DataCompositionComparisonType.LessOrEqual);
			
			List.Add(DataCompositionComparisonType.Greater);
			List.Add(DataCompositionComparisonType.GreaterOrEqual);
			
		EndIf;
		
	EndIf;
	
	If TypesInformation.ContainsStringType Then
		
		List.Add(DataCompositionComparisonType.Contains);
		List.Add(DataCompositionComparisonType.NotContains);
		
		List.Add(DataCompositionComparisonType.Like);
		List.Add(DataCompositionComparisonType.NotLike);
		
		List.Add(DataCompositionComparisonType.BeginsWith);
		List.Add(DataCompositionComparisonType.NotBeginsWith);
		
	EndIf;
	
	If TypesInformation.ReducedLengthItem Then
		
		List.Add(DataCompositionComparisonType.Filled);
		List.Add(DataCompositionComparisonType.NotFilled);
		
	EndIf;
	
	Return List;
EndFunction

Function FindTableRows(TableAttribute, RowData) Export
	If TypeOf(TableAttribute) = Type("FormDataCollection") Then // Value table.
		Return TableAttribute.FindRows(RowData);
	ElsIf TypeOf(TableAttribute) = Type("FormDataTree") Then // Value tree.
		Return FindRecursively(TableAttribute.GetItems(), RowData);
	Else
		Return Undefined;
	EndIf;
EndFunction

Function FindRecursively(RowsSet, RowData, FoundItems = Undefined)
	If FoundItems = Undefined Then
		FoundItems = New Array;
	EndIf;
	For Each TableRow In RowsSet Do
		ValuesMatch = True;
		For Each KeyAndValue In RowData Do
			If TableRow[KeyAndValue.Key] <> KeyAndValue.Value Then
				ValuesMatch = False;
				Break;
			EndIf;
		EndDo;
		If ValuesMatch Then
			FoundItems.Add(TableRow);
		EndIf;
		FindRecursively(TableRow.GetItems(), RowData, FoundItems);
	EndDo;
	Return FoundItems;
EndFunction

Procedure CastValueToType(Value, TypesDetails) Export
	If Not TypesDetails.ContainsType(TypeOf(Value)) Then
		Value = TypesDetails.AdjustValue();
	EndIf;
EndProcedure

// Picture name in the ReportSettingsIcons collection.
Function PictureIndex(Type, State = Undefined) Export
	If Type = "Group" Then
		Index = 1;
	ElsIf Type = "Item" Then
		Index = 4;
	ElsIf Type = "Group"
		Or Type = "TableGroup"
		Or Type = "ChartGroup" Then
		Index = 7;
	ElsIf Type = "Table" Then
		Index = 10;
	ElsIf Type = "Chart" Then
		Index = 11;
	ElsIf Type = "NestedObjectSettings" Then
		Index = 12;
	ElsIf Type = "DataParameters" Then
		Index = 14;
	ElsIf Type = "DataParameter" Then
		Index = 15;
	ElsIf Type = "Filters" Then
		Index = 16;
	ElsIf Type = "FilterItem" Then
		Index = 17;
	ElsIf Type = "SelectedFields" Then
		Index = 18;
	ElsIf Type = "Sorting" Then
		Index = 19;
	ElsIf Type = "ConditionalAppearance" Then
		Index = 20;
	ElsIf Type = "Settings" Then
		Index = 21;
	ElsIf Type = "Structure" Then
		Index = 22;
	ElsIf Type = "Resource" Then
		Index = 23;
	ElsIf Type = "Warning" Then
		Index = 24;
	ElsIf Type = "Error" Then
		Index = 25;
	Else
		Index = -2;
	EndIf;
	
	If State = "DeletionMark" Then
		Index = Index + 1;
	ElsIf State = "Predefined" Then
		Index = Index + 2;
	EndIf;
	
	Return Index;
EndFunction

Function UniqueKey(ReportFullName, OptionKey) Export
	Result = ReportFullName;
	If ValueIsFilled(OptionKey) Then
		Result = Result + "/VariantKey." + OptionKey;
	EndIf;
	Return Result;
EndFunction

#EndRegion
