#Region Public

// Returns a reference to the report option.
//
// Parameters:
//   Report - CatalogRef.ExtensionObjectIDs,
//           CatalogRef.MetadataObjectIDs,
//           CatalogRef.AdditionalReportsAndDataProcessors,
//           String - a reference to the report or the external report full name.
//   OptionKey - String - the report option name.
//
// Returns:
//   CatalogRef.ReportsOptions, Undefined - the report option or Undefined if the report option is 
//           unavailable due to rights.
//
Function ReportOption(Report, OptionKey) Export
	Result = Undefined;
	
	Query = New Query;
	If TypeOf(Report) = Type("CatalogRef.ExtensionObjectIDs") Then
		Query.Text =
		"SELECT ALLOWED TOP 1
		|	ReportsOptions.Variant AS ReportOption
		|FROM
		|	InformationRegister.PredefinedExtensionsVersionsReportsOptions AS ReportsOptions
		|WHERE
		|	ReportsOptions.Report = &Report
		|	AND ReportsOptions.ExtensionsVersion = &ExtensionsVersion
		|	AND ReportsOptions.VariantKey = &VariantKey";
		Query.SetParameter("ExtensionsVersion", SessionParameters.ExtensionsVersion);
	Else
		Query.Text =
		"SELECT ALLOWED TOP 1
		|	ReportsOptions.Ref AS ReportOption
		|FROM
		|	Catalog.ReportsOptions AS ReportsOptions
		|WHERE
		|	ReportsOptions.Report = &Report
		|	AND ReportsOptions.VariantKey = &VariantKey
		|
		|ORDER BY
		|	ReportsOptions.DeletionMark";
	EndIf;
	Query.SetParameter("Report", Report);
	Query.SetParameter("VariantKey", OptionKey);
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		Result = Selection.ReportOption;
	EndIf;
	
	Return Result;
EndFunction

// Returns reports (CatalogRef.ReportsOptions) that are available to the current user.
// They must be used in all queries to the "ReportsOptions" catalog table as the filter by the 
// "Report" attribute except for filtering options from external reports.
// 
//
// Returns:
//   Array - reports that are available to the current user (CatalogRef.ExtensionObjectIDs,
//            String, CatalogRef.AdditionalReportsAndDataProcessors,
//            CatalogRef.MetadataObjectIDs).
//            The item type matches the Catalogs.ReportOptions.Attributes.Report attribute type.
//
Function CurrentUserReports() Export
	
	AvailableReports = New Array(ReportsOptionsCached.AvailableReports());
	
	// Additional reports that are available to the current user.
	If Common.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
		ModuleAdditionalReportsAndDataProcessors = Common.CommonModule("AdditionalReportsAndDataProcessors");
		ModuleAdditionalReportsAndDataProcessors.OnAddAdditionalReportsAvailableForCurrentUser(AvailableReports);
	EndIf;
	
	Return AvailableReports;
	
EndFunction

// Returns the list of report options from the ReportsOptionsStorage settings storage.
// See also StandardSettingsStorageManager.GetList in Syntax Assistant.
// Unlike the platform method, the function checks access rights to the report instead of the "DataAdministration" right.
//
// Parameters:
//   ReportKey   - String - the full report name with a point.
//   User - String, UUID, 
//                  InfobaseUser, Undefined, 
//                  CatalogRef.Users - A name, ID, or reference to the user whose settings you need.
//                                                  
//                                                  If Undefined, a current user.
//
// Returns:
//   ValueList - a list of report options where:
//       * Value      - String - a report option key.
//       * Presentation - String - a report option presentation.
//
//
Function ReportOptionsKeys(ReportKey, Val User = Undefined) Export
	
	Return SettingsStorages.ReportsVariantsStorage.GetList(ReportKey, User);
	
EndFunction

// The procedure deletes options of the specified report or all reports.
// See also StandardSettingsStorageManager.Delete in Syntax Assistant.
//
// Parameters:
//   ReportKey - String, Undefined - the report full name with a point.
//                                       If Undefined, settings of all reports will be deleted.
//   OptionKey - String, Undefined - the key of the report option to be deleted.
//                                       If Undefined, all report options will be deleted.
//   User - String, UUID, 
//                  InfobaseUser, Undefined, 
//                  CatalogRef.Users - the name, ID, or reference to the user whose settings will be 
//                                                  deleted.
//                                                  If Undefined, settings of all users will be deleted.
//
Procedure DeleteReportOption(ReportKey, OptionKey, Val User) Export
	
	SettingsStorages.ReportsVariantsStorage.Delete(ReportKey, OptionKey, User);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Support for overridable modules.

// The procedure calls the report manager module to fill in its settings.
// It is used for calling from the ReportOptionsOverridable.SetUpReportsOptions.
//
// Parameters:
//   Settings       - Collection        - the parameter is passed as is from the SetUpReportsOptions procedure.
//   ReportMetadata - MetadataObject - metadata of the object that has the 
//                                        SetUpReportOptions(Settings, ReportSettings) export procedure in its manager module.
//
Procedure CustomizeReportInManagerModule(Settings, ReportMetadata) Export
	ReportSettings = ReportDetails(Settings, ReportMetadata);
	Try
		Reports[ReportMetadata.Name].CustomizeReportOptions(Settings, ReportSettings);
	Except
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Недопустимое значение параметра OptionKey в процедуре ReportsOptions.CustomizeReportInManagerModule.
			|Не удалось настроить варианты отчета из модуля менеджера по причине:
			|%1'; 
			|en = 'Invalid value of the OptionKey parameter in procedure ReportsOptions.CustomizeReportInManagerModule.
			|Cannot configure report options from manager module due to:
			|%1'; 
			|pl = 'Niedopuszczalna wartość parametru OptionKey w procedurze ReportsOptions.CustomizeReportInManagerModule.
			|Nie udało się ustawić warianty raportu z modułu menedżera z powodu:
			|%1';
			|es_ES = 'Valor inaceptable del parámetro OptionKey en el procedimiento ReportsOptions.CustomizeReportInManagerModule.
			|No se ha podido ajustar las variantes del informe del módulo del gerente a causa de:
			|%1';
			|es_CO = 'Valor inaceptable del parámetro OptionKey en el procedimiento ReportsOptions.CustomizeReportInManagerModule.
			|No se ha podido ajustar las variantes del informe del módulo del gerente a causa de:
			|%1';
			|tr = 'ReportsOptions.CustomizeReportInManagerModule prosedüründe OptionKey parametresinin kabul edilemeyen değeri. 
			| Rapor seçeneklerinin yönetici modülünden ayarlanamama nedeni: 
			|%1';
			|it = 'Valore non valido del parametro OptionKey nella procedura ReportsOptions.CustomizeReportInManagerModule.
			|Impossibile configurare varianti di report dal modulo di gestione a causa di:
			|%1';
			|de = 'Ungültiger Wert des Parameters OptionKey in der Prozedur ReportsOptions.CustomizeReportInManagerModule.
			|Die Berichtsoptionen aus dem Manager-Modul können nicht konfiguriert werden aufgrund von:
			|%1'"),
			DetailErrorDescription(ErrorInfo()));
		WriteToLog(EventLogLevel.Error, ErrorText, ReportMetadata);
	EndTry;
EndProcedure

// Returns settings of the specified report. The function is used to set up placement and common 
// report parameters in ReportOptionsOverridable.SetUpReportsOptions.
//
// Parameters:
//   Settings - Collection - used to describe settings of reports and options.
//                           The parameter is passed as is from the ReportOptionsOverridable.
//                           SetUpReportsOptions and SetUpReportOptions procedures.
//   Report - MetadataObject, CatalogRef.MetadataObjectIDs - metadata or report reference.
//
// Returns:
//   ValueTreeRow - report settings and default settings for options of this report.
//     The returned value can be used in the OptionDetails function to get option settings.
//     Attributes to change:
//       * Enabled              - Boolean - If False, the report option is not registered in the subsystem.
//       * DefaultVisibility - Boolean - if False, the report option is hidden from the report panel by default.
//       * Placement           - Map - settings describing report option placement in sections.
//           ** Key - MetadataObject - a subsystem where a report or a report version is placed.
//           ** Value - String           - settings related to placement in a subsystem (group).
//               *** ""        - output a report in a subsystem without highlighting.
//               *** "Important"  - output a report in a subsystem marked in bold.
//               *** "SeeAlso" - output the report in the "See also" group.
//       * FunctionalOptions - Array of String - names of the report option functional options.
//       * SearchSettings  - Structure - additional settings related to the search of this report option.
//           You must configure these settings only in case DCS is not used or its functionality cannot be used completely.
//           For example, DCS can be used only for parametrization and receiving data whereas the 
//           output destination is a fixed template of a spreadsheet document.
//           ** FieldDescriptions - String - names of report option fields.
//           ** FilterAndParameterDescriptions - String - names of report option settings.
//           ** Keywords - String - Additional terminology (including specific or obsolete).
//           Term separator: Chars.LF.
//           ** TemplatesNames - String - the parameter is used instead of FieldDescriptions.
//               Names of spreadsheet or text document templates that are used to extract 
//               information on field descriptions.
//               Names are separated by commas.
//               Unfortunately, unlike DCS, templates do not contain information on links between 
//               fields and their presentations. Therefore it is recommended to fill in FieldDescriptions instead of 
//               TemplateNames for correct operating of the search engine.
//       * DCSSettingsFormat - Boolean - a report uses a standard settings storage format based on 
//           the DCS mechanics, and its main forms support the standard schema of interaction 
//           between forms (parameters and the type of the return values).
//           If False, then consistency checks and some components that require the standard format 
//           will be disabled for this report.
//       * DefineFormSettings - Boolean - a report has an interface for close integration with the 
//           report form. It can redefine some form settings and subscribe to its events.
//           If True and the report is attached to the general ReportForm form, then the procedure 
//           must be defined in the report object module according to the following template:
//               
//               // Define settings of the "Report options" subsystem common report form.
//               //
//               // Parameters:
//               //  Form - ClientApplicationForm, Undefined - a report form or a report settings form.
//               //      Undefined when called without a context.
//               //   VariantKey - String, Undefined -  a predefined report option name
//               //       or UUID of a custom one.
//               //      Undefined when called without a context.
//               //   Settings - Structure - see the return value of
//               //       ReportsClientServer.GetDefaultReportSettings().
//               //
//               Procedure DefineFormSettings(Form, VariantKey, Settings) Export
//               	// Procedure code.
//               EndProcedure
//     
//     Internal attributes (read-only):
//       * Report               - <see Catalogs.ReportOptions.Attributes.Report> - a full name or reference to a report.
//       * Metadata          - MetadataObject: Report - object metadata.
//       * OptionKey        - String - Report option name.
//       * DetailsReceived    - Boolean - shows whether the row details are already received.
//           Details are generated by the OptionDetails() method.
//       * SystemInfo - Structure - another internal information.
//
Function ReportDetails(Settings, Report) Export
	IsMetadata = (TypeOf(Report) = Type("MetadataObject"));
	If IsMetadata Then
		RowReport = Settings.Rows.Find(Report, "Metadata", False);
	Else
		RowReport = Settings.Rows.Find(Report, "Report", False);
	EndIf;
	
	If RowReport = Undefined Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Недопустимое значение параметра Report в процедуре ReportsOptions.ReportDetails.
			|Отчет ""%1"" не подключен к подсистеме ""%2"". Проверьте свойство ""Хранилище вариантов"" в свойствах отчета.'; 
			|en = 'Invalid value of the Report parameter in procedure ReportsOptions.ReportDetails .
			|Report ""%1"" is not attached to subsystem ""%2"". Check the ""Option storage"" property in report properties.'; 
			|pl = 'Niedopuszczalna wartość parametru Raport w procedurze ReportsOptions.ReportDetails.
			| Raport ""%1"" nie jest podłączony do podsystemu ""%2"". Sprawdź właściwość ""Option storage"" we właściwościach raportu.';
			|es_ES = 'Valor inaceptable del parámetro Informe en el procedimiento ReportsOptions.ReportDetails
			|El informe ""%1"" no está conectado al subsistema ""%2"". Compruebe la propiedad ""Almacenamiento de variantes"" en la propiedades del informe.';
			|es_CO = 'Valor inaceptable del parámetro Informe en el procedimiento ReportsOptions.ReportDetails
			|El informe ""%1"" no está conectado al subsistema ""%2"". Compruebe la propiedad ""Almacenamiento de variantes"" en la propiedades del informe.';
			|tr = 'ReportsOptions.ReportDetails prosedüründe Rapor parametresinin izin verilmeyen değeri. 
			| Rapor ""%1"", ""%2"" alt sisteme bağlı değil. Rapor özelliklerinde ""Seçenek deposu"" özelliğini kontrol edin.';
			|it = 'Valore non valido del parametro Report nella procedura ReportsOptions.ReportDetails.
			|Report ""%1"" non è collegato al sottosistema ""%2"". Controllare la proprietà ""Archivio varianti"" nelle proprietà del report.';
			|de = 'Ungültiger Wert des Berichtsparameters in der Prozedur ReportsOptions.ReportDetails.
			|Der Bericht ""%1"" ist nicht an das Subsystem ""%2"" angehängt. Überprüfen Sie die Eigenschaft ""Option Speicherung"" in den Berichtseigenschaften.'"),
			String(Report),
			ReportsOptionsClientServer.SubsystemDescription(""));
	EndIf;
	
	Return RowReport;
EndFunction

// It finds report option settings. The function is used for configuring placement.
// For usage in ReportOptionsOverridable.SetUpReportsOptions.
//
// Parameters:
//   Settings - Collection - used to describe settings of reports and options.
//       The parameter is passed as is from the SetUpReportsOptions and SetUpReportOptions procedures.
//   Report - TreeRow, MetadataObject - a settings description, metadata, or a report reference.
//   OptionKey - String - a report option name as it is defined in the data composition schema.
//
// Returns:
//   ValueTreeRow - report option settings.
//     Attributes to change:
//       * Enabled              - Boolean - If False, the report option is not registered in the subsystem.
//       * DefaultVisibility - Boolean - if False, the report option is hidden from the report panel by default.
//       * Description         - String - a report option description.
//       * Details             - String - a report option tooltip.
//       * Placement           - Map - settings describing report option placement in sections.
//           ** Key - MetadataObject - a subsystem where a report or a report version is placed.
//           ** Value - String           - settings related to placement in a subsystem (group).
//               *** ""        - output an option in a subsystem without highlighting.
//               *** "Important"  - output an option in a subsystem marked in bold.
//               *** "SeeAlso" - output an option in the "See also" group.
//       * FunctionalOptions - Array of String - names of the report option functional options.
//       * SearchSettings  - Structure - additional settings related to the search of this report option.
//           You must configure these settings only in case DCS is not used or its functionality cannot be used completely.
//           For example, DCS can be used only for parametrization and receiving data whereas the 
//           output destination is a fixed template of a spreadsheet document.
//           ** FieldDescriptions - String - names of report option fields.
//           ** FilterAndParameterDescriptions - String - names of report option settings.
//           ** Keywords - String - Additional terminology (including specific or obsolete).
//           Term separator: Chars.LF.
//           ** TemplatesNames - String - the parameter is used instead of FieldDescriptions.
//               Names of spreadsheet or text document templates that are used to extract 
//               information on field descriptions.
//               Names are separated by commas.
//               Unfortunately, unlike DCS, templates do not contain information on links between 
//               fields and their presentations. Therefore it is recommended to fill in FieldDescriptions instead of 
//               TemplateNames for correct operating of the search engine.
//       * DCSSettingsFormat - Boolean - a report uses a standard settings storage format based on 
//           the DCS mechanics, and its main forms support the standard schema of interaction 
//           between forms (parameters and the type of the return values).
//           If False, then consistency checks and some components that require the standard format 
//           will be disabled for this report.
//       * DefineFormSettings - Boolean - a report has an interface for close integration with the 
//           report form. It can redefine some form settings and subscribe to its events.
//           If True and the report is attached to the general ReportForm form, then the procedure 
//           must be defined in the report object module according to the following template:
//               
//               // Define settings of the "Report options" subsystem common report form.
//               //
//               // Parameters:
//               //  Form - ClientApplicationForm, Undefined - a report form or a report settings form.
//               //      Undefined when called without a context.
//               //   VariantKey - String, Undefined -  a predefined report option name
//               //       or UUID of a custom one.
//               //      Undefined when called without a context.
//               //   Settings - Structure - see the return value of
//               //       ReportsClientServer.GetDefaultReportSettings().
//               //
//               Procedure DefineFormSettings(Form, VariantKey, Settings) Export
//               	// Procedure code.
//               EndProcedure
//     
//     Internal attributes (read-only):
//       * Report               - <see Catalogs.ReportOptions.Attributes.Report> - a full name or reference to a report.
//       * Metadata          - MetadataObject: Report - object metadata.
//       * OptionKey        - String - Report option name.
//       * DetailsReceived    - Boolean - shows whether the row details are already received.
//           Details are generated by the OptionDetails() method.
//       * SystemInfo - Structure - another internal information.
//
Function OptionDetails(Settings, Report, OptionKey) Export
	If TypeOf(Report) = Type("ValueTreeRow") Then
		RowReport = Report;
	Else
		RowReport = ReportDetails(Settings, Report);
	EndIf;
	
	If OptionKey = "" Then
		RowOption = RowReport.MainOption;
	Else
		RowOption = RowReport.Rows.Find(OptionKey, "VariantKey", False);
	EndIf;
	
	If RowOption = Undefined Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Недопустимое значение параметра OptionKey в процедуре ReportsOptions.OptionDetails:
				|вариант ""%1"" отсутствует в отчете ""%2"".'; 
				|en = 'Invalid value of the OptionKey parameter in procedure ReportsOptions.OptionDetails:
				|option ""%1"" missing in report ""%2"".'; 
				|pl = 'Niedopuszczalna wartość parametru OptionKey w procedurze ReportsOptions.OptionDetails:
				|brak wariantu ""%1"" w raporcie ""%2"".';
				|es_ES = 'Valor inaceptable del parámetro OptionKey en el procedimiento ReportsOptions.OptionDetails: no hay 
				|variante ""%1"" en el informe ""%2"".';
				|es_CO = 'Valor inaceptable del parámetro OptionKey en el procedimiento ReportsOptions.OptionDetails: no hay 
				|variante ""%1"" en el informe ""%2"".';
				|tr = 'ReportsOptions.OptionDetailsprosedüründe OptionKey parametresinin izin verilmeyen değeri: 
				| seçenek ""%1"" ""%2"" raporunda mevcut değil.';
				|it = 'Valore non valido per il parametro OptionKey nella procedura ReportsOptions.OptionDetails:
				|la variante ""%1"" non è presente nel report ""%2"".';
				|de = 'Ungültiger Wert des Parameters OptionKey in der Prozedur ReportsOptions.OptionDetails:
				|Option ""%1"" fehlt im Bericht ""%2"".'"),
			OptionKey,
			RowReport.Metadata.Name);
	EndIf;
	
	FillOptionRowDetails(RowOption, RowReport);
	
	Return RowOption;
EndFunction

// The procedure sets the output mode for Reports and Options in report panels.
// To be called from the ReportOptionsOverridable.SetUpReportsOptions procedure of the overridable 
// module and from the SetUpReportOptions procedure of the report object module.
//
// Parameters:
//   Settings - Collection - The parameter is passed as is from the relevant parameter of the 
//       SetUpReportsOptions and SetUpReportOptions procedures.
//   ReportOrSubsystem - ValueTreeRow, MetadataObject: Report, MetadataObject: Subsystem -
//       Details of a report or subsystem that are subject to the output mode configuration.
//       If a subsystem is passed, the mode is set for all reports of this subsystem recursively.
//   GroupByReports - Boolean, String - the report hyperlink output mode in the report panel:
//       - True, "ByReports" - options are grouped by reports.
//           By default, report panels output only a main report option. Other options of the report 
//           are displayed under the main one and are hidden. However, they can be found by the 
//           search or enabled by check boxes in the setup mode.
//           The main option is the first predefined option in the report schema.
//           This mode was introduced in version 2.2.2. It reduces the number of hyperlinks displayed in report panels.
//       - False, "ByOptions" - all report options are considered independent. They are visible by 
//           default and are displayed independently in report panels.
//           This mode was used in version 2.2.1 and earlier.
//
Procedure SetOutputModeInReportPanes(Settings, ReportOrSubsystem, GroupByReports) Export
	If TypeOf(GroupByReports) <> Type("Boolean") Then
		GroupByReports = (GroupByReports = Upper("ByReports"));
	EndIf;
	If TypeOf(ReportOrSubsystem) = Type("ValueTreeRow")
		Or Metadata.Reports.Contains(ReportOrSubsystem) Then
		SetReportOutputModeInReportsPanels(Settings, ReportOrSubsystem, GroupByReports);
	Else
		Subsystems = New Array;
		Subsystems.Add(ReportOrSubsystem);
		Count = 1;
		ProcessedObjects = New Array;
		While Count > 0 Do
			Count = Count - 1;
			Subsystem = Subsystems[0];
			Subsystems.Delete(0);
			For Each NestedSubsystem In Subsystem.Subsystems Do
				Count = Count + 1;
				Subsystems.Add(NestedSubsystem);
			EndDo;
			For Each MetadataObject In ReportOrSubsystem.Content Do
				If ProcessedObjects.Find(MetadataObject) = Undefined Then
					ProcessedObjects.Add(MetadataObject);
					If Metadata.Reports.Contains(MetadataObject) Then
						SetReportOutputModeInReportsPanels(Settings, MetadataObject, GroupByReports);
					EndIf;
				EndIf;
			EndDo;
		EndDo;
	EndIf;
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// To call from reports.

// Updates content of the UserReportSettings catalog after saving the new setting.
//   Called in the same name handler of the report form after the form code execution.
//
// Parameters:
//   Form - ClientApplicationForm - a report form.
//   Settings - MetadataObject - the parameter is passed as is from the OnSaveUserSettingsAtServer.
//
Procedure OnSaveUserSettingsAtServer(Form, Settings) Export
	
	FormAttributes = New Structure("ObjectKey, OptionRef");
	FillPropertyValues(FormAttributes, Form);
	If Not ValueIsFilled(FormAttributes.ObjectKey)
		Or Not ValueIsFilled(FormAttributes.OptionRef) Then
		ReportObject = Form.FormAttributeToValue("Report");
		ReportMetadata = ReportObject.Metadata();
		If Not ValueIsFilled(FormAttributes.ObjectKey) Then
			FormAttributes.ObjectKey = ReportMetadata.FullName();
		EndIf;
		If Not ValueIsFilled(FormAttributes.OptionRef) Then
			ReportInformation = GenerateReportInformationByFullName(FormAttributes.ObjectKey);
			If NOT ValueIsFilled(ReportInformation.ErrorText) Then
				ReportRef = ReportInformation.Report;
			Else
				ReportRef = FormAttributes.ObjectKey;
			EndIf;
			FormAttributes.OptionRef = ReportOption(ReportRef, Form.CurrentVariantKey);
		EndIf;
	EndIf;
	
	SettingsKey = FormAttributes.ObjectKey + "/" + Form.CurrentVariantKey;
	SettingsList = ReportsUserSettingsStorage.GetList(SettingsKey);
	SettingsCount = SettingsList.Count();
	UserRef = Users.AuthorizedUser();
	
	QueryText =
	"SELECT ALLOWED
	|	*
	|FROM
	|	Catalog.UserReportSettings AS UserReportSettings
	|WHERE
	|	UserReportSettings.Variant = &OptionRef
	|	AND UserReportSettings.User = &UserRef
	|
	|ORDER BY
	|	UserReportSettings.DeletionMark";
	
	Query = New Query;
	Query.SetParameter("OptionRef", FormAttributes.OptionRef);
	Query.SetParameter("UserRef", UserRef);
	Query.Text = QueryText;
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		
		ListItem = SettingsList.FindByValue(Selection.UserSettingKey);
		
		DeletionMark = (ListItem = Undefined);
		If DeletionMark <> Selection.DeletionMark Then
			SettingObject = Selection.Ref.GetObject();
			SettingObject.SetDeletionMark(DeletionMark);
		EndIf;
		If DeletionMark Then
			If SettingsCount = 0 Then
				Break;
			Else
				Continue;
			EndIf;
		EndIf;
		
		If Selection.Description <> ListItem.Presentation Then
			SettingObject = Selection.Ref.GetObject();
			SettingObject.Description = ListItem.Presentation;
			// The lock is not set as user settings are cut according to the users, so competitive work is not 
			// expected.
			SettingObject.Write();
		EndIf;
		
		SettingsList.Delete(ListItem);
		SettingsCount = SettingsCount - 1;
	EndDo;
	
	For Each ListItem In SettingsList Do
		SettingObject = Catalogs.UserReportSettings.CreateItem();
		SettingObject.Description                  = ListItem.Presentation;
		SettingObject.UserSettingKey = ListItem.Value;
		SettingObject.Variant                       = FormAttributes.OptionRef;
		SettingObject.User                  = UserRef;
		// The lock is not set as user settings are cut according to the users, so competitive work is not 
		// expected.
		SettingObject.Write();
	EndDo;
	
EndProcedure

// Extracts information on tables used in a schema or query.
//   The calling code handles exceptions (for example, if an incorrect query text was passed).
//
// Parameters:
//   Object - DataCompositionSchema, String - Report schema or query text.
//
// Returns:
//   Array - table names used in a schema or query.
//
// Example:
//	// Call from the native form of the report using DCS.
//	UsedTables = ReportsOptions.UsedTables(FormAttributeToValue(Report).DataCompositionSchema).
//	ReportsOptions.CheckUsedTables(UsedTables).
//	// Call from the OnComposeResult handler of the report using DCS.
//	UsedTables = ReportOptions,.UsedTables(ThisObject.DataCompositionSchema);
//	ReportsOptions.CheckUsedTables(UsedTables).
//	// Call from the OnComposeResult handler of the report using query.
//	UsedTables = ReportOptions.UsedTables(QueryText);
//	ReportsOptions.CheckUsedTables(UsedTables).
//
Function UsedTables(Object) Export
	Tables = New Array;
	If TypeOf(Object) = Type("DataCompositionSchema") Then
		RegisterDataSetsTables(Tables, Object.DataSets);
	ElsIf TypeOf(Object) = Type("String") Then
		RegisterQueryTables(Tables, Object);
	EndIf;
	Return Tables;
EndFunction

// Checks whether tables used in the schema or query are updated and inform the user about it.
//   Check is executed by the InfobaseUpdate.ObjectProcessed() method.
//   The calling code handles exceptions (for example, if an incorrect query text was passed).
//
// Parameters:
//   Object - DataCompositionSchema - Report schema.
//       - String - a query text.
//       - Array - table names used by the report.
//           * String - a table name.
//   Message - Boolean - when True and tables used by the report have not yet been updated, a 
//       message like The report can contain incorrect data will be output.
//       Optional. Default value is True.
//
// Returns:
//   Boolean - True when there are tables in the table list that are not yet updated.
//
// Example:
//	//Call from the native form of the report.
//	ReportsOptions.CheckUsedTables(FormAttributeToValue("Report").DataCompositionSchema);
//	//Call from the OnComposeResult handler of the report.
//	ReportsOptions.CheckUsedTables(ThisObject.DataCompositionSchema);
//	//Call on query execution.
//	ReportOptions.CheckUsedTables(QueryText);
//
Function CheckUsedTables(Object, Message = True) Export
	If TypeOf(Object) = Type("Array") Then
		UsedTables = Object;
	Else
		UsedTables = UsedTables(Object);
	EndIf;
	For Each FullName In UsedTables Do
		If Not InfobaseUpdate.ObjectProcessed(FullName).Processed Then
			If Message Then
				CommonClientServer.MessageToUser(DataIsBeingUpdatedMessage());
			EndIf;
			Return True;
		EndIf;
	EndDo;
	Return False;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// For calling from applied configuration update handlers.

// Resets user settings of specified reports.
//
// Parameters:
//   Key - MetadataObject: Report - metadata of the report for which settings reset is required.
//       - CatalogRef.ReportsOptions - option of the report for which settings reset is required.
//       - String - a full name of the report option for which settings reset is required.
//                  Filled in the <NameOfReport>/<NameOfOption> formate.
//                  If you pass "*", all configuration report settings will be reset.
//   SettingsTypes - Structure - optional. Types of user settings, that have to be reset.
//       Structure keys are also optional. The default value is indicated in parentheses.
//       * FilterItem              - Boolean - (False) clear the  "DataCompositionFilterItem" setting.
//       * SettingsParameterValue  - Boolean - (False) clear the "DataCompositionSettingsParameterValue" setting.
//       * SelectedFields              - Boolean - (taken from the Other key) Reset the DataCompositionSelectedFields setting.
//       * Order                    - Boolean - (taken from the Other key) Reset the DataCompositionOrder setting.
//       * ConditionalAppearanceItem - Boolean - (taken from the Other key) Reset the DataCompositionConditionalAppearanceItem setting.
//       * Other                     - Boolean - (True) Reset other settings not explicitly described in the structure.
//
Procedure ResetUserSettings(varKey, SettingsTypes = Undefined) Export
	CommonClientServer.CheckParameter(
		"ReportsOptions.ResetUserSettings",
		"Key",
		varKey,
		New TypeDescription("String, MetadataObject, CatalogRef.ReportsOptions"));
	
	OptionsKeys = New Array; // The final list of keys to be cleared.
	
	// The list of keys can be filled from the query or you can pass one specific key from the outside.
	Query = New Query;
	QueryTemplate =
	"SELECT
	|	ISNULL(ReportsOptions.Report.Name, ReportsOptions.Report.ObjectName) AS ReportName,
	|	ReportsOptions.VariantKey
	|FROM
	|	Catalog.ReportsOptions AS ReportsOptions
	|WHERE
	|	&Condition";
	If varKey = "*" Then
		Query.Text = StrReplace(QueryTemplate, "&Condition", "ReportType = VALUE(Enum.ReportTypes.Internal)");
	ElsIf TypeOf(varKey) = Type("MetadataObject") Then
		Query.Text = StrReplace(QueryTemplate, "&Condition", "Report = &Report");
		Query.SetParameter("Report", Common.MetadataObjectID(varKey));
	ElsIf TypeOf(varKey) = Type("CatalogRef.ReportsOptions") Then
		Query.Text = StrReplace(QueryTemplate, "&Condition", "Ref = &Ref");
		Query.SetParameter("Ref", varKey);
	ElsIf TypeOf(varKey) = Type("String") Then
		OptionsKeys.Add(varKey);
	Else
		Raise NStr("ru = 'Некорректный тип параметра ""Отчет""'; en = 'Incorrect type of the ""Report"" parameter'; pl = 'Niepoprawny typ parametru ""Raport""';es_ES = 'Tipo incorrecto del parámetro ""Informe""';es_CO = 'Tipo incorrecto del parámetro ""Informe""';tr = '""Rapor"" parametresinin yanlış türü';it = 'Tipo non corretto del parametro ""Report""';de = 'Falscher Parametertyp ""Bericht""'");
	EndIf;
	
	
	If Not IsBlankString(Query.Text) Then
		Selection = Query.Execute().Select();
		While Selection.Next() Do
			OptionsKeys.Add(Selection.ReportName +"/"+ Selection.VariantKey);
		EndDo;
	EndIf;
	
	If SettingsTypes = Undefined Then
		SettingsTypes = New Structure;
	EndIf;
	ReportsOptionsClientServer.AddKeyToStructure(SettingsTypes, "FilterItem", True);
	ReportsOptionsClientServer.AddKeyToStructure(SettingsTypes, "SettingsParameterValue", True);
	ResetOtherSettings = CommonClientServer.StructureProperty(SettingsTypes, "OtherItems", True);
	
	SetPrivilegedMode(True);
	
	For Each OptionFullName In OptionsKeys Do
		ObjectKey = "Report." + OptionFullName + "/CurrentUserSettings";
		StorageSelection = SystemSettingsStorage.Select(New Structure("ObjectKey", ObjectKey));
		SuccessiveReadingErrors = 0;
		While True Do
			Try
				GotSelectionItem = StorageSelection.Next();
				SuccessiveReadingErrors = 0;
			Except
				GotSelectionItem = Undefined;
				SuccessiveReadingErrors = SuccessiveReadingErrors + 1;
				WriteToLog(EventLogLevel.Error, 
					NStr("ru = 'В процессе выборки пользовательских настроек отчетов из системного хранилища возникла ошибка:'; en = 'An error occurred when selecting custom report setting from the system storage:'; pl = 'W procesie wyboru ustawień użytkownika raportów z pamięci systemowej wystąpił błąd:';es_ES = 'Durante la selección de los ajustes de usuario de los informes del almacenamiento de sistema ha ocurrido un error:';es_CO = 'Durante la selección de los ajustes de usuario de los informes del almacenamiento de sistema ha ocurrido un error:';tr = 'Standart depolama alanından kullanıcı ayarları seçilirken bir hata oluştu:';it = 'Durante la procedura di selezione delle impostazioni dei report personalizzate dall''archivio di sistema, si è verificato un errore:';de = 'Bei der Auswahl der benutzerdefinierten Berichtseinstellungen aus dem Systemspeicher ist ein Fehler aufgetreten:'")
					+ Chars.LF
					+ DetailErrorDescription(ErrorInfo()));
			EndTry;
			
			If GotSelectionItem = False Then
				Break;
			ElsIf GotSelectionItem = Undefined Then
				If SuccessiveReadingErrors > 100 Then
					Break;
				Else
					Continue;
				EndIf;
			EndIf;
			
			DCUserSettings = StorageSelection.Settings;
			If TypeOf(DCUserSettings) <> Type("DataCompositionUserSettings") Then
				Continue;
			EndIf;
			HasChanges = False;
			Count = DCUserSettings.Items.Count();
			For Number = 1 To Count Do
				ReverseIndex = Count - Number;
				DCUserSetting = DCUserSettings.Items[ReverseIndex];
				Type = ReportsClientServer.SettingTypeAsString(TypeOf(DCUserSetting));
				Reset = CommonClientServer.StructureProperty(SettingsTypes, Type, ResetOtherSettings);
				If Reset Then
					DCUserSettings.Items.Delete(ReverseIndex);
					HasChanges = True;
				EndIf;
			EndDo;
			If HasChanges Then
				Common.SystemSettingsStorageSave(
					StorageSelection.ObjectKey,
					StorageSelection.SettingsKey,
					DCUserSettings,
					,
					StorageSelection.User);
			EndIf;
		EndDo;
	EndDo;
EndProcedure

// Moves user options from standard options storage to the subsystem storage.
//   Used on partial deployment - when the ReportsOptionsStorage is set not for the entire 
//   configuration, but in the properties of specific reports connected to the subsystem.
//   It is recommended for using in specific version update handlers.
//
// Parameters:
//   ReportsNames - String - Optional. Report names, separated by commas.
//
// Example:
//	// Moving all user report options from upon update.
//	ReportsOptions.MoveReportsOptionsFromStandardStorage();
//	// Or moving user report options, transferred to the "Report options" subsystem storage.
//	ReportsOptions.MoveReportsOptionsFromStandardStorage("EventLogAnalysis, ExpiringTasksOnDate");
//
Procedure MoveUsersOptionsFromStandardStorage(ReportsNames = "") Export
	ProcedurePresentation = NStr("ru = 'Прямая конвертация вариантов отчетов'; en = 'Direct conversion of report options'; pl = 'Konwersja bezpośrednia opcji sprawozdań';es_ES = 'Conversión directa de las opciones de informes';es_CO = 'Conversión directa de las opciones de informes';tr = 'Rapor seçeneklerinin doğrudan dönüşümü';it = 'Conversione diretta delle varianti report';de = 'Direkte Konvertierung von Berichtsoptionen'");
	WriteProcedureStartToLog(ProcedurePresentation);
	
	// The result that will be saved in the storage.
	ReportOptionsTable = Common.CommonSettingsStorageLoad("TransferReportOptions", "OptionsTable", , , "");
	If TypeOf(ReportOptionsTable) <> Type("ValueTable") Or ReportOptionsTable.Count() = 0 Then
		ReportOptionsTable = New ValueTable;
		ReportOptionsTable.Columns.Add("Report",     TypesDetailsString());
		ReportOptionsTable.Columns.Add("Variant",   TypesDetailsString());
		ReportOptionsTable.Columns.Add("Author",     TypesDetailsString());
		ReportOptionsTable.Columns.Add("Settings", New TypeDescription("ValueStorage"));
		ReportOptionsTable.Columns.Add("ReportPresentation",   TypesDetailsString());
		ReportOptionsTable.Columns.Add("OptionPresentation", TypesDetailsString());
		ReportOptionsTable.Columns.Add("AuthorID",   New TypeDescription("UUID"));
	EndIf;
	
	RemoveAll = (ReportsNames = "" Or ReportsNames = "*");
	ArrayOfObjectsKeysToDelete = New Array;
	
	StorageSelection = ReportsVariantsStorage.Select(NewFilterByObjectKey(ReportsNames));
	SuccessiveReadingErrors = 0;
	While True Do
		Try
			GotSelectionItem = StorageSelection.Next();
			SuccessiveReadingErrors = 0;
		Except
			GotSelectionItem = Undefined;
			SuccessiveReadingErrors = SuccessiveReadingErrors + 1;
			WriteToLog(EventLogLevel.Error,
				NStr("ru = 'В процессе выборки вариантов отчетов из стандартного хранилища возникла ошибка:'; en = 'An error occurred when selecting report options from the standard storage:'; pl = 'Wystąpił błąd podczas wybierania wariantów sprawozdania z pamięci:';es_ES = 'Ha ocurrido un error al seleccionar las opciones de informes desde el almacenamiento estándar:';es_CO = 'Ha ocurrido un error al seleccionar las opciones de informes desde el almacenamiento estándar:';tr = 'Standart depolama alanından rapor seçenekleri seçilirken bir hata oluştu:';it = 'Un errore si è registrato durante la selezione delle varianti report dall''archivio standard:';de = 'Beim Auswählen der Berichtsoptionen aus dem Standardspeicher ist ein Fehler aufgetreten:'")
				+ Chars.LF
				+ DetailErrorDescription(ErrorInfo()));
		EndTry;
		
		If GotSelectionItem = False Then
			If ReportsNames = "" Or ReportsNames = "*" Then
				Break;
			Else
				StorageSelection = ReportsVariantsStorage.Select(NewFilterByObjectKey(ReportsNames));
				Continue;
			EndIf;
		ElsIf GotSelectionItem = Undefined Then
			If SuccessiveReadingErrors > 100 Then
				Break;
			Else
				Continue;
			EndIf;
		EndIf;
		
		// Skipping not connected internal reports.
		ReportMetadata = Metadata.FindByFullName(StorageSelection.ObjectKey);
		If ReportMetadata <> Undefined Then
			StorageMetadata = ReportMetadata.VariantsStorage;
			If StorageMetadata = Undefined Or StorageMetadata.Name <> "ReportsVariantsStorage" Then
				RemoveAll = False;
				Continue;
			EndIf;
		EndIf;
		
		// All external report options will be transferred as it is impossible to define whether they are 
		// attached to the subsystem storage.
		ArrayOfObjectsKeysToDelete.Add(StorageSelection.ObjectKey);
		
		InfobaseUser = InfoBaseUsers.FindByName(StorageSelection.User);
		If InfobaseUser = Undefined Then
			User = Catalogs.Users.FindByDescription(StorageSelection.User, True);
			If Not ValueIsFilled(User) Then
				Continue;
			EndIf;
			UserID = User.IBUserID;
		Else
			UserID = InfobaseUser.UUID;
		EndIf;
		
		TableRow = ReportOptionsTable.Add();
		TableRow.Report     = StorageSelection.ObjectKey;
		TableRow.Variant   = StorageSelection.SettingsKey;
		TableRow.Author     = StorageSelection.User;
		TableRow.Settings = New ValueStorage(StorageSelection.Settings, New Deflation(9));
		TableRow.OptionPresentation = StorageSelection.Presentation;
		TableRow.AuthorID   = UserID;
		If ReportMetadata = Undefined Then
			TableRow.ReportPresentation = StorageSelection.ObjectKey;
		Else
			TableRow.ReportPresentation = ReportMetadata.Presentation();
		EndIf;
	EndDo;
	
	// Clear the standard storage.
	If RemoveAll Then
		ReportsVariantsStorage.Delete(Undefined, Undefined, Undefined);
	Else
		For Each ObjectKey In ArrayOfObjectsKeysToDelete Do
			ReportsVariantsStorage.Delete(ObjectKey, Undefined, Undefined);
		EndDo;
	EndIf;
	
	// Execution result
	WriteProcedureCompletionToLog(ProcedurePresentation);
	
	// Import options to the subsystem storage.
	ImportUserOptions(ReportOptionsTable);
EndProcedure

// Imports to the subsystem storage reports options previously saved from the system option storage 
//   to the common settings storage.
//   It is used to import report options upon full or partial deployment.
//   At full deployment it can be called from the TransferReportsOptions data processor.
//   It is recommended for using in specific version update handlers.
//
// Parameters:
//   OptionsTable - ValueTable - Optional. Used in internal scripts.
//       * Report   - String - full report name in the format of "Report.<ReportName>".
//       * Option - String - report option name.
//       * Author   - String - user name.
//       * Setting - ValueStorage - DataCompositionUserSettings.
//       * ReportPresentation   - String - report presentation.
//       * VariantPresentation - String - an option presentation.
//       * AuthorID - UUID - user ID.
//
Procedure ImportUserOptions(ReportOptionsTable = Undefined) Export
	
	If ReportOptionsTable = Undefined Then
		ReportOptionsTable = Common.CommonSettingsStorageLoad("TransferReportOptions", "OptionsTable", , , "");
	EndIf;
	
	If TypeOf(ReportOptionsTable) <> Type("ValueTable") Or ReportOptionsTable.Count() = 0 Then
		Return;
	EndIf;
	
	ProcedurePresentation = NStr("ru = 'Завершить конвертацию вариантов отчетов'; en = 'Complete conversion of report options'; pl = 'Pełna konwersja opcji sprawozdań';es_ES = 'Conversión completa de las opciones de informes';es_CO = 'Conversión completa de las opciones de informes';tr = 'Rapor seçeneklerinin tam dönüşümü';it = 'Completare la conversione delle varianti report';de = 'Vollständige Konvertierung der Berichtsoptionen'");
	WriteProcedureStartToLog(ProcedurePresentation);
	
	// Replacing column names for catalog structure.
	ReportOptionsTable.Columns.Report.Name = "ReportFullName";
	ReportOptionsTable.Columns.Variant.Name = "VariantKey";
	ReportOptionsTable.Columns.OptionPresentation.Name = "Description";
	
	// Transforming report names into MOID catalog references.
	ReportOptionsTable.Columns.Add("Report", Metadata.Catalogs.ReportsOptions.Attributes.Report.Type);
	ReportOptionsTable.Columns.Add("Defined", New TypeDescription("Boolean"));
	ReportOptionsTable.Columns.Add("ReportType", Metadata.Catalogs.ReportsOptions.Attributes.ReportType.Type);
	For Each TableRow In ReportOptionsTable Do
		ReportInformation = GenerateReportInformationByFullName(TableRow.ReportFullName);
		
		// Validate the result
		If TypeOf(ReportInformation.ErrorText) = Type("String") Then
			WriteToLog(EventLogLevel.Error, ReportInformation.ErrorText);
			Continue;
		EndIf;
		
		TableRow.Defined = True;
		FillPropertyValues(TableRow, ReportInformation, "Report, ReportType");
	EndDo;
	
	ReportOptionsTable.Sort("ReportFullName Asc, VariantKey Asc");
	
	// Existing report options.
	QueryText =
	"SELECT
	|	OptionsTable.Report,
	|	OptionsTable.ReportFullName,
	|	OptionsTable.ReportType,
	|	OptionsTable.VariantKey,
	|	OptionsTable.Author
	|INTO ttOptions
	|FROM
	|	&OptionsTable AS OptionsTable
	|WHERE
	|	OptionsTable.Defined = TRUE
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ttOptions.Report,
	|	ttOptions.ReportFullName,
	|	ttOptions.ReportType,
	|	ttOptions.VariantKey,
	|	ReportsOptions.Ref,
	|	UsersByName.Ref AS UserByName
	|FROM
	|	ttOptions AS ttOptions
	|		LEFT JOIN Catalog.Users AS UsersByName
	|		ON ttOptions.Author = UsersByName.Description
	|			AND (UsersByName.DeletionMark = FALSE)
	|		LEFT JOIN Catalog.ReportsOptions AS ReportsOptions
	|		ON ttOptions.Report = ReportsOptions.Report
	|			AND ttOptions.VariantKey = ReportsOptions.VariantKey
	|			AND ttOptions.ReportType = ReportsOptions.ReportType";
	
	Query = New Query;
	Query.SetParameter("OptionsTable", ReportOptionsTable);
	Query.Text = QueryText;
	
	DBOptions = Query.Execute().Unload();
	DBOptions.Indexes.Add("Report, VariantKey");
	
	// Option authors
	QueryText =
	"SELECT
	|	Users.Ref AS User,
	|	Users.IBUserID AS ID
	|FROM
	|	Catalog.Users AS Users
	|WHERE
	|	Users.IBUserID IN(&IDs)
	|	AND Users.DeletionMark = FALSE";
	
	Query = New Query;
	Query.SetParameter("IDs", ReportOptionsTable.UnloadColumn("AuthorID"));
	Query.Text = QueryText;
	
	UsersByID = Query.Execute().Unload();
	
	ReportsSubsystems = PlacingReportsToSubsystems();
	
	// Import options to the subsystem storage.
	DefinedOptions = ReportOptionsTable.FindRows(New Structure("Defined", True));
	For Each TableRow In DefinedOptions Do
		FoundItems = DBOptions.FindRows(New Structure("Report, VariantKey", TableRow.Report, TableRow.VariantKey));
		DBOption = FoundItems[0];
		
		// If an option is already imported into the "Report options" catalog, do not import it.
		If ValueIsFilled(DBOption.Ref) Then
			Continue;
		EndIf;
		
		// CatalogObject
		OptionObject = Catalogs.ReportsOptions.CreateItem();
		
		// Already prepared parameters.
		FillPropertyValues(OptionObject, TableRow, "Description, Report, ReportType, VariantKey");
		
		// Settings
		Settings = TableRow.Settings;
		If TypeOf(Settings) = Type("ValueStorage") Then
			Settings = Settings.Get();
		EndIf;
		OptionObject.Settings = New ValueStorage(Settings);
		
		// Only user report options are stored in the standard storage.
		OptionObject.Custom = True;
		OptionObject.AvailableToAuthorOnly = True;
		
		// Option author
		UserByID = UsersByID.Find(TableRow.AuthorID, "ID");
		If UserByID <> Undefined AND ValueIsFilled(UserByID.User) Then
			OptionObject.Author = UserByID.User;
		ElsIf DBOption <> Undefined AND ValueIsFilled(DBOption.UserByName) Then
			OptionObject.Author = DBOption.UserByName;
		Else
			WriteToLog(EventLogLevel.Error,
				StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Вариант ""%1"" отчета ""%2"": не найден автор ""%3""'; en = 'Option ""%1"" of report ""%2"": author ""%3"" was not found'; pl = 'Opcja ""%1"" sprawozdania ""%2"": nie znaleziono autora ""%3""';es_ES = 'Opción ""%1"" del informe ""%2"": autor ""%3"" no se ha encontrado';es_CO = 'Opción ""%1"" del informe ""%2"": autor ""%3"" no se ha encontrado';tr = '""%2"" raporunun ""%1"" seçeneği: ""%3"" yazarı bulunamadı';it = 'La variante ""%1"" del report ""%2"": autore ""%3"" non è stata trovata';de = 'Option ""%1"" des Berichts ""%2"": Autor ""%3"" wurde nicht gefunden'"),
					OptionObject.Description,
					TableRow.ReportPresentation,
					TableRow.Author),
				OptionObject.Ref);
		EndIf;
		
		// Since user report options are moved, placement settings can only be taken from report metadata.
		// 
		FoundItems = ReportsSubsystems.FindRows(New Structure("ReportFullName", TableRow.ReportFullName));
		For Each RowSubsystem In FoundItems Do
			SubsystemRef = Common.MetadataObjectID(RowSubsystem.SubsystemMetadata);
			If TypeOf(SubsystemRef) = Type("String") Then
				Continue;
			EndIf;
			RowSection = OptionObject.Placement.Add();
			RowSection.Use = True;
			RowSection.Subsystem = SubsystemRef;
		EndDo;
		
		// Report options are created, thus competitive work with them is excluded.
		OptionObject.Write();
	EndDo;
	
	// Clearing
	Common.CommonSettingsStorageDelete("TransferReportOptions", "OptionsTable", "");
	
	WriteProcedureCompletionToLog(ProcedurePresentation);
EndProcedure

#Region ObsoleteProceduresAndFunctions

// Obsolete. You must stop using it.
//
// Returns:
//   ValueTable - Used sections.
//
Function UsedSections() Export
	Result = New ValueTable;
	Result.Columns.Add("Ref",          New TypeDescription("CatalogRef.MetadataObjectIDs"));
	Result.Columns.Add("Metadata",      New TypeDescription("MetadataObject, String"));
	Result.Columns.Add("Name",             TypesDetailsString());
	Result.Columns.Add("Presentation",   TypesDetailsString());
	Result.Columns.Add("PanelCaption", TypesDetailsString());
	
	HomePageID = ReportsOptionsClientServer.HomePageID();
	
	SectionsList = New ValueList;
	
	ReportsOptionsOverridable.DefineSectionsWithReportOptions(SectionsList);
	
	If Common.SubsystemExists("StandardSubsystems.ApplicationSettings") Then
		ModuleDataProcessorsControlPanelSSL = Common.CommonModule("DataProcessors.SSLAdministrationPanel");
		ModuleDataProcessorsControlPanelSSL.OnDefineSectionsWithReportOptions(SectionsList);
	EndIf;
	
	For Each ListItem In SectionsList Do
		MetadataSection = ListItem.Value;
		If ValueIsFilled(ListItem.Presentation) Then
			CaptionPattern = ListItem.Presentation;
		Else
			CaptionPattern = NStr("ru = 'Отчеты раздела ""%1""'; en = '""%1"" reports'; pl = 'Sprawozdania ""%1""';es_ES = 'Informes ""%1""';es_CO = 'Informes ""%1""';tr = '""%1"" raporlar';it = 'Sezione report ""%1""';de = 'Berichte von ""%1""'");
		EndIf;
		
		Row = Result.Add();
		Row.Ref = Common.MetadataObjectID(MetadataSection);
		If MetadataSection = HomePageID Then
			Row.Metadata    = HomePageID;
			Row.Name           = HomePageID;
			Row.Presentation = NStr("ru = 'Начальная страница'; en = 'Home page'; pl = 'Strona początkowa';es_ES = 'Página principal';es_CO = 'Página principal';tr = 'Ana sayfa';it = 'Pagina iniziale';de = 'Startseite'");
		Else
			Row.Metadata    = MetadataSection;
			Row.Name           = MetadataSection.Name;
			Row.Presentation = MetadataSection.Presentation();
		EndIf;
		Row.PanelCaption = StrReplace(CaptionPattern, "%1", Row.Presentation); // Cannot go to the StrTemplate.
	EndDo;
	
	Return Result;
EndFunction

// Obsolete. You must stop using it.
// Full update of the report option search index.
// Call from the  OnAddUpdateHandlers of configuration.
// Warning: it should be called only once from the final application module.
// Not indented for calling from libraries.
//
// Parameters:
//   Handlers - Collection - it is passed "as it is" from the called procedure.
//   Version - String - configuration version, migrating to which you need to fully update the 
//       search index.
//     It is recommended to specify the latest functional version, during whose update changes were 
//       made to the presentations of metadata objects or their attributes that can be displayed in 
//       reports.
//       
//     Set if necessary.
//
// Example:
//	ReportOptions.AddCompleteUpdateHandlers(Handlers, "11.1.7.8");
//
Procedure AddCompleteUpdateHandlers(Handlers, Version) Export
	Return;
EndProcedure

// Obsolete. Use ReportOption.
// Receives a report option reference by a set of key attributes.
//
// Parameters:
//   Report - CatalogRef.ExtensionObjectIDs,
//           CatalogRef.MetadataObjectIDs,
//           CatalogRef.AdditionalReportsAndDataProcessors,
//           String - a report reference or a full name of the external report.
//   OptionKey - String - the report option name.
//
// Returns:
//   * CatalogRef.ReportsOptions - when option is found.
//   * Undefined                     - when option is not found.
//
Function GetRef(Report, OptionKey) Export
	
	Return ReportOption(Report, OptionKey);
	
EndFunction

#EndRegion

#EndRegion

#Region Internal

// The function gets the report object from the report option reference.
//
// Parameters:
//   Parameters - Structure - parameters of attaching and generating a report.
//       * OptionRef - CatalogRef.ReportsOptions - a report option reference.
//       * RefOfReport   - Arbitrary - a report reference.
//       * OptionKey   - String - a predefined report option name or a user report option ID.
//       * FormID - Undefined, UUID - an ID of the form from which the report is attached.
//
// Returns:
//   Structure - report parameters including the report Object.
//       * RefOfReport - Arbitrary     - a report reference.
//       * FullName    - String           - the full name of the report.
//       * Metadata   - MetadataObject - report metadata.
//       * Object       - ReportObject.<Report name>, ExternalReport - a report object.
//           ** SettingsComposer - DataCompositionSettingsComposer - report settings.
//           ** DataCompositionSchema - DataCompositionSchema - Report schema.
//       * OptionKey - String           - a predefined report option name or a user report option ID.
//       * SchemaURL   - String           - an address in the temporary storage where the report schema is placed.
//       * Success        - Boolean           - True if the report is attached.
//       * ErrorText  - String           - an error text.
//
// Usage locations:
//   ReportMailing.InitReport().
//
Function AttachReportAndImportSettings(Parameters) Export
	Result = New Structure("OptionRef, ReportRef, VariantKey, FormSettings,
		|Object, Metadata, FullName,
		|DCSchema, SchemaURL, SchemaModified, DCSettings, DCUserSettings,
		|ErrorText, Success");
	FillPropertyValues(Result, Parameters);
	Result.Success = False;
	Result.SchemaModified = False;
	
	// Support the ability to directly select additional reports references in reports mailings.
	If TypeOf(Result.DCSettings) <> Type("DataCompositionSettings")
		AND Result.VariantKey = Undefined
		AND Result.Object = Undefined
		AND TypeOf(Result.OptionRef) = ReportsOptionsClientServer.AdditionalReportRefType() Then
		// Automatically detecting a key and option reference if only a reference of additional report is passed.
		Result.ReportRef = Result.OptionRef;
		Result.OptionRef = Undefined;
		ConnectingReport = AttachReportObject(Result.ReportRef, True);
		If Not ConnectingReport.Success Then
			Result.ErrorText = ConnectingReport.ErrorText;
			Return Result;
		EndIf;
		FillPropertyValues(Result, ConnectingReport, "Object, Metadata, FullName");
		ConnectingReport.Clear();
		If Result.Object.DataCompositionSchema = Undefined Then
			Result.Success = True;
			Return Result;
		EndIf;
		DCSettingsOption = Result.Object.DataCompositionSchema.SettingVariants.Get(0);
		Result.VariantKey = DCSettingsOption.Name;
		Result.DCSettings  = DCSettingsOption.Settings;
		Result.OptionRef = ReportOption(Result.ReportRef, Result.VariantKey);
	EndIf;
	
	MustReadReportRef = (Result.Object = Undefined AND Result.ReportRef = Undefined);
	MustReadSettings = (TypeOf(Result.DCSettings) <> Type("DataCompositionSettings"));
	If MustReadReportRef Or MustReadSettings Then
		If TypeOf(Result.OptionRef) <> Type("CatalogRef.ReportsOptions")
			Or Not ValueIsFilled(Result.OptionRef) Then
			If Not MustReadReportRef AND Result.VariantKey <> Undefined Then
				Result.OptionRef = ReportOption(Result.ReportRef, Result.VariantKey);
			EndIf;
			If Result.OptionRef = Undefined Then
				Result.ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = 'В методе ""%1"" не указаны параметры ""%2"".'; en = 'Parameters ""%2"" are not specified in method ""%1"" .'; pl = 'W metodzie ""%1"" nie wskazane parametry ""%2"".';es_ES = 'En el método ""%1"" no están indicados los parámetros ""%2"".';es_CO = 'En el método ""%1"" no están indicados los parámetros ""%2"".';tr = '""%1"" yönteminde ""%2"" parametreleri belirtilmedi.';it = 'Parametri ""%2"" non sono specificati nel metodo ""%1"" .';de = 'Die Parameter ""%2"" werden in der Methode ""%1"" nicht angegeben.'"),
					"AttachReportAndImportSettings",
					"OptionRef, ReportRef, VariantKey");
				Return Result;
			EndIf;
		EndIf;
		PropertyNames = "VariantKey" + ?(MustReadReportRef, ", Report", "") + ?(MustReadSettings, ", Settings", "");
		OptionProperties = Common.ObjectAttributesValues(Result.OptionRef, PropertyNames);
		Result.VariantKey = OptionProperties.VariantKey;
		If MustReadReportRef Then
			Result.ReportRef = OptionProperties.Report;
		EndIf;
		If MustReadSettings Then
			Result.DCSettings = OptionProperties.Settings.Get();
			MustReadSettings = (TypeOf(Result.DCSettings) <> Type("DataCompositionSettings"));
		EndIf;
	EndIf;
	
	If Result.Object = Undefined Then
		ConnectingReport = AttachReportObject(Result.ReportRef, True);
		If Not ConnectingReport.Success Then
			Result.ErrorText = ConnectingReport.ErrorText;
			Return Result;
		EndIf;
		FillPropertyValues(Result, ConnectingReport, "Object, Metadata, FullName");
		ConnectingReport.Clear();
		ConnectingReport = Undefined;
	ElsIf Result.FullName = Undefined Then
		Result.Metadata = Result.Object.Metadata();
		Result.FullName = Result.Metadata.FullName();
	EndIf;
	
	ReportObject = Result.Object;
	DCSettingsComposer = ReportObject.SettingsComposer;
	
	Result.FormSettings = ReportFormSettings(Result.ReportRef, Result.VariantKey, ReportObject);
	
	If ReportObject.DataCompositionSchema = Undefined Then
		Result.Success = True;
		Return Result;
	EndIf;
	
	// Reading settings.
	If MustReadSettings Then
		DCSettingsOptions = ReportObject.DataCompositionSchema.SettingVariants;
		DCSettingsOption = DCSettingsOptions.Find(Result.VariantKey);
		If DCSettingsOption = Undefined Then
			Result.ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Вариант ""%1"" (ключ ""%2"") не найден в схеме отчета ""%3"".'; en = 'The ""%1"" option (key ""%2"") is not found in the ""%3"" report scheme.'; pl = 'Wariantu ""%1"" (klucz ""%2"") nie znaleziono w schemacie raportu ""%3"".';es_ES = 'La variante ""%1"" (clave ""%2"") no está encontrada en el esquema del informe ""%3"".';es_CO = 'La variante ""%1"" (clave ""%2"") no está encontrada en el esquema del informe ""%3"".';tr = '""%1"" seçeneği (anahtar ""%2"") ""%3"" rapor şemasında bulunamadı.';it = 'La variante ""%1"" (chiave ""%2"") non è stata trovata nello schema di report ""%3"".';de = 'Die Option ""%1"" (Schlüssel ""%2"") wird im Berichtsschema ""%3"" nicht gefunden.'"),
				String(Result.OptionRef),
				Result.VariantKey,
				String(Result.ReportRef));
			Return Result;
		EndIf;
		Result.DCSettings = DCSettingsOption.Settings;
	EndIf;
	
	// Initializing schema.
	SchemaURLFilled = (TypeOf(Result.SchemaURL) = Type("String") AND IsTempStorageURL(Result.SchemaURL));
	If SchemaURLFilled AND TypeOf(Result.DCSchema) <> Type("DataCompositionSchema") Then
		Result.DCSchema = GetFromTempStorage(Result.SchemaURL);
	EndIf;
	
	Result.SchemaModified = (TypeOf(Result.DCSchema) = Type("DataCompositionSchema"));
	If Result.SchemaModified Then
		ReportObject.DataCompositionSchema = Result.DCSchema;
	EndIf;
	
	If Not SchemaURLFilled AND TypeOf(ReportObject.DataCompositionSchema) = Type("DataCompositionSchema") Then
		FormID = CommonClientServer.StructureProperty(Parameters, "FormID");
		If TypeOf(FormID) = Type("UUID") Then
			SchemaURLFilled = True;
			Result.SchemaURL = PutToTempStorage(ReportObject.DataCompositionSchema, FormID);
		ElsIf Result.SchemaModified Then
			SchemaURLFilled = True;
			Result.SchemaURL = PutToTempStorage(ReportObject.DataCompositionSchema);
		EndIf;
	EndIf;
	
	If SchemaURLFilled Then
		DCSettingsComposer.Initialize(New DataCompositionAvailableSettingsSource(Result.SchemaURL));
	EndIf;
	
	If Result.FormSettings.Events.BeforeImportSettingsToComposer Then
		SchemaKey = CommonClientServer.StructureProperty(Parameters, "SchemaKey");
		ReportObject.BeforeImportSettingsToComposer(
			Result,
			SchemaKey,
			Result.VariantKey,
			Result.DCSettings,
			Result.DCUserSettings);
	EndIf;
	
	FixedDCSettings = CommonClientServer.StructureProperty(Parameters, "FixedDCSettings");
	If TypeOf(FixedDCSettings) = Type("DataCompositionSettings")
		AND DCSettingsComposer.FixedSettings <> FixedDCSettings Then
		DCSettingsComposer.LoadFixedSettings(FixedDCSettings);
	EndIf;
	
	ReportsClientServer.LoadSettings(DCSettingsComposer, Result.DCSettings, Result.DCUserSettings);
	
	Result.Success = True;
	Return Result;
EndFunction

// Updates additional report options when writing it.
//
// Usage locations:
//   Catalog.AdditionalReportsAndDataProcessors.OnWriteGlobalReport().
//
Procedure OnWriteAdditionalReport(CurrentObject, Cancel, ExternalObject) Export
	
	If Not ReportsOptionsCached.InsertRight() Then
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Недостаточно прав доступа для записи вариантов дополнительного отчета ""%1"".'; en = 'Insufficient access rights to write options of additional report ""%1"".'; pl = 'Niewystarczające prawa dostępu do opcji zapisu dodatkowego raportu ""%1"".';es_ES = 'Insuficientes derechos de acceso para grabar las opciones del informe adicional ""%1"".';es_CO = 'Insuficientes derechos de acceso para grabar las opciones del informe adicional ""%1"".';tr = 'Ek rapor ""%1"" seçeneklerini yazmak için yetersiz erişim hakları.';it = 'Permessi insufficienti per scrivere le varianti del report aggiuntivo ""%1"".';de = 'Unzureichende Zugriffsrechte zum Schreiben von Optionen des zusätzlichen Berichts ""%1"".'"),
			CurrentObject.Description);
		WriteToLog(EventLogLevel.Error, ErrorText, CurrentObject.Ref);
		CommonClientServer.MessageToUser(ErrorText);
		Return;
	EndIf;
	
	DeletionMark = CurrentObject.DeletionMark;
	If ExternalObject = Undefined
		Or Not CurrentObject.UseOptionStorage
		Or Not CurrentObject.AdditionalProperties.PublicationUsed Then
		DeletionMark = True;
	EndIf;
	
	PredefinedOptions = New ValueList;
	If DeletionMark = False AND ExternalObject <> Undefined Then
		ReportMetadata = ExternalObject.Metadata();
		DCSchemaMetadata = ReportMetadata.MainDataCompositionSchema;
		If DCSchemaMetadata <> Undefined Then
			DCSchema = ExternalObject.GetTemplate(DCSchemaMetadata.Name);
			For Each DCSettingsOption In DCSchema.SettingVariants Do
				PredefinedOptions.Add(DCSettingsOption.Name, DCSettingsOption.Presentation);
			EndDo;
		Else
			PredefinedOptions.Add("", ReportMetadata.Presentation());
		EndIf;
	EndIf;
	
	// When removing deletion mark from an additional report, it is not removed for user variants marked 
	// for deletion interactively.
	QueryText =
	"SELECT ALLOWED
	|	ReportsOptions.Ref,
	|	ReportsOptions.VariantKey,
	|	ReportsOptions.Custom,
	|	ReportsOptions.DeletionMark,
	|	ReportsOptions.Description
	|FROM
	|	Catalog.ReportsOptions AS ReportsOptions
	|WHERE
	|	ReportsOptions.Report = &Report
	|	AND NOT(ReportsOptions.Custom
	|				AND ReportsOptions.InteractiveSetDeletionMark)";
	
	Query = New Query;
	Query.SetParameter("Report", CurrentObject.Ref);
	If DeletionMark = True Then
		// When marking an additional report for deletion, all report oprtions are also marked for deletion.
		QueryText = StrReplace(
			QueryText,
			"AND NOT(ReportsOptions.Custom
			|				AND ReportsOptions.InteractiveSetDeletionMark)",
			"");
	EndIf;
	Query.Text = QueryText;
	
	// Set deletion mark.
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		
		OptionDeletionMark = DeletionMark;
		ListItem = PredefinedOptions.FindByValue(Selection.VariantKey);
		If Not OptionDeletionMark AND Not Selection.Custom AND ListItem = Undefined Then
			// A predefined item that is not found in the list of predefined items for this report.
			OptionDeletionMark = True;
		EndIf;
		
		If Selection.DeletionMark <> OptionDeletionMark Then
			OptionObject = Selection.Ref.GetObject();
			OptionObject.AdditionalProperties.Insert("PredefinedObjectsFilling", True);
			If OptionDeletionMark Then
				OptionObject.AdditionalProperties.Insert("IndexSchema", False);
			Else
				OptionObject.AdditionalProperties.Insert("ReportObject", ExternalObject);
			EndIf;
			OptionObject.SetDeletionMark(OptionDeletionMark);
		EndIf;
		
		If ListItem <> Undefined Then
			PredefinedOptions.Delete(ListItem);
			If Selection.Description <> ListItem.Presentation Then
				OptionObject = Selection.Ref.GetObject();
				OptionObject.Description = ListItem.Presentation;
				OptionObject.AdditionalProperties.Insert("ReportObject", ExternalObject);
				// All existing predefined report options are updated, so competitive work is unlikely.
				OptionObject.Write();
			EndIf;
		EndIf;
	EndDo;
	
	If Not DeletionMark Then
		// Register new report options
		For Each ListItem In PredefinedOptions Do
			OptionObject = Catalogs.ReportsOptions.CreateItem();
			OptionObject.Report                = CurrentObject.Ref;
			OptionObject.ReportType            = Enums.ReportTypes.Additional;
			OptionObject.VariantKey         = ListItem.Value;
			OptionObject.Description         = ListItem.Presentation;
			OptionObject.Custom     = False;
			OptionObject.VisibleByDefault = True;
			OptionObject.AdditionalProperties.Insert("ReportObject", ExternalObject);
			// Predefined report options are created, thus competitive work is excluded.
			OptionObject.Write();
		EndDo;
	EndIf;
	
EndProcedure

// Gets options of the passed report and their presentations.
//
// Usage locations:
//   UsersInternal.OnReceiveUserReportOptions().
//
Procedure UserReportOptions(ReportMetadata, InfobaseUser, ReportOptionTable, StandardProcessing) Export
	
	ReportKey = "Report" + "." + ReportMetadata.Name;
	AllReportOptions = ReportOptionsKeys(ReportKey, InfobaseUser);
	
	For Each ReportOption In AllReportOptions Do
		
		CatalogItem = Catalogs.ReportsOptions.FindByDescription(ReportOption.Presentation);
		
		If CatalogItem <> Undefined
			AND CatalogItem.AvailableToAuthorOnly Then
			
			ReportOptionRow = ReportOptionTable.Add();
			ReportOptionRow.ObjectKey = "Report." + ReportMetadata.Name;
			ReportOptionRow.VariantKey = ReportOption.Value;
			ReportOptionRow.Presentation = ReportOption.Presentation;
			ReportOptionRow.StandardProcessing = False;
			
			StandardProcessing = False;
			
		ElsIf CatalogItem <> Undefined Then
			StandardProcessing = False;
		EndIf;
		
	EndDo;
	
EndProcedure

// Deletes the passed report option from the report option storage.
//
// Usage locations:
//   UsersInternal.OnDeleteUserReportOptions().
//
Procedure DeleteUserReportOption(ReportOptionInfo, InfobaseUser, StandardProcessing) Export
	
	If ReportOptionInfo.StandardProcessing Then
		Return;
	EndIf;
	
	StandardProcessing = False;
	DeleteReportOption(ReportOptionInfo.ObjectKey, ReportOptionInfo.VariantKey, InfobaseUser);
	
EndProcedure

// Generates additional parameters to open a report option.
//
// Parameters:
//   OptionRef - CatalogRef.ReportsOptions - a reference of the report option being opened..
//
Function OpeningParameters(OptionRef) Export
	OpeningParameters = New Structure("Ref, Report, ReportType, ReportName, VariantKey, MeasurementsKey");
	If TypeOf(OptionRef) = ReportsOptionsClientServer.AdditionalReportRefType() Then
		// Support the ability to directly select additional reports references in reports mailings.
		OpeningParameters.Report     = OptionRef;
		OpeningParameters.ReportType = "Additional";
	Else
		QueryText =
		"SELECT ALLOWED
		|	ReportsOptions.Report,
		|	ReportsOptions.ReportType,
		|	ReportsOptions.VariantKey,
		|	ReportsOptions.PredefinedVariant.MeasurementsKey AS MeasurementsKey
		|FROM
		|	Catalog.ReportsOptions AS ReportsOptions
		|WHERE
		|	ReportsOptions.Ref = &Ref";
		
		Query = New Query;
		Query.SetParameter("Ref", OptionRef);
		Query.Text = QueryText;
		
		Selection = Query.Execute().Select();
		If Not Selection.Next() Then
			Raise StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Недостаточно прав для открытия варианта ""%1"".'; en = 'Insufficient rights to open option ""%1"".'; pl = 'Niewystarczające uprawnienia do otwarcia wariantu ""%1"".';es_ES = 'Insuficientes derechos para abrir la variante ""%1"".';es_CO = 'Insuficientes derechos para abrir la variante ""%1"".';tr = '""%1"" seçeneğini açmak için yetersiz haklar.';it = 'Permessi insufficienti per aprire la variante ""%1"".';de = 'Unzureichende Rechte zum Öffnen der Variante ""%1"".'"), String(OptionRef));
		EndIf;
		
		FillPropertyValues(OpeningParameters, Selection);
		OpeningParameters.Ref    = OptionRef;
		OpeningParameters.ReportType = ReportsOptionsClientServer.ReportByStringType(Selection.ReportType, Selection.Report);
	EndIf;
	
	OnAttachReport(OpeningParameters);
	
	Return OpeningParameters;
EndFunction

// Attaching additional reports.
Procedure OnAttachReport(OpeningParameters) Export
	
	OpeningParameters.Insert("Connected", False);
	
	If OpeningParameters.ReportType = "Internal"
		Or OpeningParameters.ReportType = "Extension" Then
		
		MetadataOfReport = Catalogs.MetadataObjectIDs.MetadataObjectByID(
			OpeningParameters.Report, True);
		
		If TypeOf(MetadataOfReport) <> Type("MetadataObject") Then
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Не удалось открыть отчет ""%1"".
					|Возможно, было отключено расширение конфигурации с этим отчетом.'; 
					|en = 'Cannot open the ""%1"" report. 
					|The configuration extension with this report might have been disabled.'; 
					|pl = 'Nie można otworzyć sprawozdania ""%1"".
					|Być może rozszerzenie konfiguracji z tym sprawozdaniem zostało wyłączone.';
					|es_ES = 'No se puede abrir el informe ""%1"".
					|Puede ser que la extensión de la configuración con este informe se haya desactivado.';
					|es_CO = 'No se puede abrir el informe ""%1"".
					|Puede ser que la extensión de la configuración con este informe se haya desactivado.';
					|tr = '""%1"" Raporu açılamıyor. 
					|Bu raporla yapılan yapılandırma uzantısı devre dışı bırakılmış olabilir.';
					|it = 'Impossibile aprire il report ""%1"". 
					|L''estensione di configurazione potrebbe essere stata disabilitata con questo report.';
					|de = 'Der Bericht ""%1"" kann nicht geöffnet werden.
					|Möglicherweise wurde die Konfigurationserweiterung mit diesem Bericht deaktiviert.'"),
				OpeningParameters.Report);
		EndIf;
		OpeningParameters.ReportName = MetadataOfReport.Name;
		OpeningParameters.Connected = True; // Configuration reports are always attached.
		
	ElsIf OpeningParameters.ReportType = "Extension" Then
		If Metadata.Reports.Find(OpeningParameters.ReportName) = Undefined Then
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Не удалось открыть отчет ""%1"".
					|Возможно, было отключено расширение конфигурации с этим отчетом.'; 
					|en = 'Cannot open the ""%1"" report. 
					|The configuration extension with this report might have been disabled.'; 
					|pl = 'Nie można otworzyć sprawozdania ""%1"".
					|Być może rozszerzenie konfiguracji z tym sprawozdaniem zostało wyłączone.';
					|es_ES = 'No se puede abrir el informe ""%1"".
					|Puede ser que la extensión de la configuración con este informe se haya desactivado.';
					|es_CO = 'No se puede abrir el informe ""%1"".
					|Puede ser que la extensión de la configuración con este informe se haya desactivado.';
					|tr = '""%1"" Raporu açılamıyor. 
					|Bu raporla yapılan yapılandırma uzantısı devre dışı bırakılmış olabilir.';
					|it = 'Impossibile aprire il report ""%1"". 
					|L''estensione di configurazione potrebbe essere stata disabilitata con questo report.';
					|de = 'Der Bericht ""%1"" kann nicht geöffnet werden.
					|Möglicherweise wurde die Konfigurationserweiterung mit diesem Bericht deaktiviert.'"),
				OpeningParameters.ReportName);
		EndIf;
		OpeningParameters.Connected = True;
	ElsIf OpeningParameters.ReportType = "Additional" Then
		If Common.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
			ModuleAdditionalReportsAndDataProcessors = Common.CommonModule("AdditionalReportsAndDataProcessors");
			ModuleAdditionalReportsAndDataProcessors.OnAttachReport(OpeningParameters);
		EndIf;
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Other procedures of internal interface.

// The function updates subsystem data considering the application mode.
//   Usage example: after clearing settings storage.
//
// Parameters:
//   Settings - Structure - optional. Update settings.
//       * Configuration - Boolean - Optional. Update configuration metadata cache.
//       * Extensions   - Boolean - Optional. Update extension metadata cache.
//       * SharedData       - Boolean - optional. Update shared data.
//       * SeparatedData - Boolean - optional. Update separated data.
//       * RealTime - Boolean - optional. Real-time data update.
//       * Deferred  - Boolean - optional. Deferred data update.
//       * Full      - Boolean - optional. Do not consider hash during the deferred data update.
//
Function Refresh(Settings = Undefined) Export
	
	If Settings = Undefined Then
		Settings = New Structure;
	EndIf;
	
	Default = New Structure("Configuration, Extensions, SharedData, SeparatedData, Nonexclusive, Deferred, Full");
	If Settings.Count() < Default.Count() Then
		If Common.DataSeparationEnabled() Then
			If Common.SeparatedDataUsageAvailable() Then
				Default.SharedData       = False;
				Default.SeparatedData = True;
			Else // Shared session.
				Default.SharedData       = True;
				Default.SeparatedData = False;
			EndIf;
		Else
			If Common.IsStandaloneWorkplace() Then // SWP.
				Default.SharedData       = False;
				Default.SeparatedData = True;
			Else // Box.
				Default.SharedData       = True;
				Default.SeparatedData = True;
			EndIf;
		EndIf;
		Default.Configuration = True;
		Default.Extensions   = Default.SeparatedData;
		Default.Nonexclusive  = True;
		Default.Deferred   = False;
		Default.Full       = False;
		CommonClientServer.SupplementStructure(Settings, Default, False);
	EndIf;
	
	Result = New Structure;
	Result.Insert("HasChanges", False);
	
	If Settings.Nonexclusive Then
		
		If Settings.SharedData Then
			
			If Settings.Configuration Then
				InterimResult = CommonDataNonexclusiveUpdate("ConfigurationCommonData", Undefined);
				Result.Insert("NonexclusiveUpdate_CommonData_Configuration", InterimResult);
				If InterimResult <> Undefined AND InterimResult.HasChanges Then
					Result.HasChanges = True;
				EndIf;
			EndIf;
			
			If Settings.Extensions Then
				InterimResult = CommonDataNonexclusiveUpdate("ExtensionsCommonData", Undefined);
				Result.Insert("NonexclusiveUpdate_CommonData_Extensions", InterimResult);
				If InterimResult <> Undefined AND InterimResult.HasChanges Then
					Result.HasChanges = True;
				EndIf;
			EndIf;
			
		EndIf;
		
		If Settings.SeparatedData Then
			
			If Settings.Configuration Then
				InterimResult = SeparatedDataNonexclusiveUpdate("SeparatedConfigurationData");
				Result.Insert("NonexclusiveUpdate_SeparatedData_Configuration", InterimResult);
				If InterimResult <> Undefined AND InterimResult.HasChanges Then
					Result.HasChanges = True;
				EndIf;
			EndIf;
			
			If Settings.Extensions Then
				InterimResult = SeparatedDataNonexclusiveUpdate("SeparatedExtensionData");
				Result.Insert("NonexclusiveUpdate_SeparatedData_Extensions", InterimResult);
				If InterimResult <> Undefined AND InterimResult.HasChanges Then
					Result.HasChanges = True;
				EndIf;
			EndIf;
			
		EndIf;
		
	EndIf;
	
	If Settings.Deferred Then
		
		If Settings.SharedData Then
			
			If Settings.Configuration Then
				InterimResult = DeferredDataUpdate("ConfigurationCommonData", Settings.Full);
				Result.Insert("DeferredUpdate_CommonData_Configuration", InterimResult);
				If InterimResult <> Undefined AND InterimResult.HasChanges Then
					Result.HasChanges = True;
				EndIf;
			EndIf;
			
			If Settings.Extensions Then
				InterimResult = DeferredDataUpdate("ExtensionsCommonData", Settings.Full);
				Result.Insert("DeferredUpdate_CommonData_Extensions", InterimResult);
				If InterimResult <> Undefined AND InterimResult.HasChanges Then
					Result.HasChanges = True;
				EndIf;
			EndIf;
			
		EndIf;
		
		If Settings.SeparatedData Then
			
			If Settings.Configuration Then
				InterimResult = DeferredDataUpdate("SeparatedConfigurationData", Settings.Full);
				Result.Insert("DeferredUpdate_SeparatedData_Configuration", InterimResult);
				If InterimResult <> Undefined AND InterimResult.HasChanges Then
					Result.HasChanges = True;
				EndIf;
			EndIf;
			
			If Settings.Extensions Then
				InterimResult = DeferredDataUpdate("SeparatedExtensionData", Settings.Full);
				Result.Insert("DeferredUpdate_SeparatedData_Extensions", InterimResult);
				If InterimResult <> Undefined AND InterimResult.HasChanges Then
					Result.HasChanges = True;
				EndIf;
			EndIf;
			
		EndIf;
		
	EndIf;
	
	Return Result;
EndFunction

// Generates a report with the specified parameters.
//
// Parameters:
//   Parameters - Structure - parameters of attaching and generating a report.
//       * OptionRef - CatalogRef.ReportsOptions - a report option reference.
//       * RefOfReport   - Arbitrary - a report reference.
//       * OptionKey   - String - a predefined report option name or a user report option ID.
//       * FormID - Undefined, UUID - an ID of the form from which the report is attached.
//   CheckFilling - Boolean - if True, filling will be checked before generation.
//   GetCheckBoxEmpty - Boolean - if True, an analysis of filling is conducted after generation.
//
// Returns:
//   Structure - generation result.
//
// Usage locations:
//   ReportsMailing.GenerateReport().
//
// See also:
//   <Method>().
//
Function GenerateReport(Val Parameters, Val CheckFilling, Val GetCheckBoxEmpty) Export
	Result = New Structure("SpreadsheetDocument, Details,
		|OptionRef, ReportRef, VariantKey,
		|Object, Metadata, FullName,
		|DCSchema, SchemaURL, SchemaModified, FormSettings,
		|DCSettings, VariantModified,
		|DCUserSettings, UserSettingsModified,
		|ErrorText, Success, DataStillUpdating");
	
	Result.Success = False;
	Result.SpreadsheetDocument = New SpreadsheetDocument;
	Result.VariantModified = False;
	Result.UserSettingsModified = False;
	Result.DataStillUpdating = False;
	If GetCheckBoxEmpty Then
		Result.Insert("IsEmpty", False);
	EndIf;
	
	If Parameters.Property("Connection") Then
		Attachment = Parameters.Connection;
	Else
		Attachment = AttachReportAndImportSettings(Parameters);
	EndIf;
	FillPropertyValues(Result, Attachment); // , "Object, Metadata, FullName, OptionKey, DCSchema, SchemaURL, SchemaModified, FormSettings"
	If Not Attachment.Success Then
		Result.ErrorText = NStr("ru = 'Не удалось сформировать отчет:'; en = 'Cannot generate the report:'; pl = 'Nie udało się utworzyć raportu:';es_ES = 'No se ha podido generar el informe:';es_CO = 'No se ha podido generar el informe:';tr = 'Rapor oluşturulamadı:';it = 'Impossibile generare il report:';de = 'Der Bericht konnte nicht generiert werden:'") + Chars.LF + Attachment.ErrorText;
		Return Result;
	EndIf;
	
	ReportObject = Result.Object;
	DCSettingsComposer = ReportObject.SettingsComposer;
	
	CheckResult = CheckEmptyFilters(DCSettingsComposer.Settings.Filter.Items);
	FillPropertyValues(Result, CheckResult);
	If Not Result.Success Then
		Return Result;
	EndIf;
	
	AuxProperties = DCSettingsComposer.UserSettings.AdditionalProperties;
	AuxProperties.Insert("VariantKey", Result.VariantKey);
	
	// Checking if data, by which report is being generated, is correct.
	
	If CheckFilling Then
		OriginalUserMessages = GetUserMessages(True);
		CheckPassed = ReportObject.CheckFilling();
		UserMessages = GetUserMessages(True);
		For Each Message In OriginalUserMessages Do
			Message.Message();
		EndDo;
		If Not CheckPassed Then
			Result.ErrorText = NStr("ru = 'Отчет не прошел проверку заполнения:'; en = 'Report did not pass the population check:'; pl = 'Raport nie przeszedł weryfikacji wypełnienia:';es_ES = 'El informe no ha pasado la comprobación de relleno:';es_CO = 'El informe no ha pasado la comprobación de relleno:';tr = 'Raporun doldurma şekli doğrulanamadı:';it = 'Il report non ha passato il controllo compilazione:';de = 'Der Bericht hat die Vollständigkeitsprüfung nicht bestanden:'");
			For Each Message In UserMessages Do
				Result.ErrorText = Result.ErrorText + Chars.LF + Message.Text;
			EndDo;
			Return Result;
		EndIf;
	EndIf;
	
	Try
		UsedTables = UsedTables(Result.DCSchema);
		UsedTables.Add(Result.FullName);
		If Result.FormSettings.Events.OnDefineUsedTables Then
			ReportObject.OnDefineUsedTables(Result.VariantKey, UsedTables);
		EndIf;
		Result.DataStillUpdating = CheckUsedTables(UsedTables, False);
	Except
		ErrorText = NStr("ru = 'Не удалось определить используемые таблицы:'; en = 'Cannot determine the used tables:'; pl = 'Nie można określić używanych tabel:';es_ES = 'No se ha podido determinar las tablas usadas:';es_CO = 'No se ha podido determinar las tablas usadas:';tr = 'Kullanılan tablolar belirlenemedi:';it = 'Non è possibile determinare le tabelle utilizzate:';de = 'Die verwendeten Tabellen konnten nicht ermittelt werden:'");
		ErrorText = ErrorText + Chars.LF + DetailErrorDescription(ErrorInfo());
		WriteToLog(EventLogLevel.Error, ErrorText, Result.OptionRef);
	EndTry;
	
	// Generating and assessing the speed.
	
	KeyOperationName = CommonClientServer.StructureProperty(Parameters, "KeyOperationName");
	RunMeasurements = TypeOf(KeyOperationName) = Type("String") AND Not IsBlankString(KeyOperationName) AND RunMeasurements();
	If RunMeasurements Then
		KeyOperationComment = CommonClientServer.StructureProperty(Parameters, "KeyOperationComment");
		ModulePerformanceMonitor = Common.CommonModule("PerformanceMonitor");
		StartTime = ModulePerformanceMonitor.StartTimeMeasurement();
	EndIf;
	
	ReportObject.ComposeResult(Result.SpreadsheetDocument, Result.Details);
	
	If RunMeasurements Then
		ModulePerformanceMonitor.EndTechnologicalTimeMeasurement(
			KeyOperationName,
			StartTime,
			1,
			KeyOperationComment);
	EndIf;
	
	// Register the result.
	
	If AuxProperties <> DCSettingsComposer.UserSettings.AdditionalProperties Then
		NewAuxProperties = DCSettingsComposer.UserSettings.AdditionalProperties;
		CommonClientServer.SupplementStructure(NewAuxProperties, AuxProperties, False);
		AuxProperties = NewAuxProperties;
	EndIf;
	
	ItemModified = CommonClientServer.StructureProperty(AuxProperties, "VariantModified");
	If ItemModified = True Then
		Result.VariantModified = True;
		Result.DCSettings = DCSettingsComposer.Settings;
	EndIf;
	
	ItemsModified = CommonClientServer.StructureProperty(AuxProperties, "UserSettingsModified");
	If Result.VariantModified Or ItemsModified = True Then
		Result.UserSettingsModified = True;
		Result.DCUserSettings = DCSettingsComposer.UserSettings;
	EndIf;
	
	If GetCheckBoxEmpty Then
		If AuxProperties.Property("ReportIsBlank") Then
			IsEmpty = AuxProperties.ReportIsBlank;
		Else
			IsEmpty = ReportsServer.ReportIsBlank(ReportObject);
		EndIf;
		Result.Insert("IsEmpty", IsEmpty);
	EndIf;
	
	PrintSettings = Result.FormSettings.Print;
	PrintSettings.Insert("PrintParametersKey", ReportsClientServer.UniqueKey(Result.FullName, Result.VariantKey));
	FillPropertyValues(Result.SpreadsheetDocument, PrintSettings);
	
	Result.Success = True;
	
	// Clearing garbage.
	
	AuxProperties.Delete("VariantModified");
	AuxProperties.Delete("UserSettingsModified");
	AuxProperties.Delete("VariantKey");
	AuxProperties.Delete("ReportIsBlank");
	
	Return Result;
EndFunction

// Detalizes report availability by rights and functional options.
Function ReportsAvailability(ReportsReferences) Export

	Result = New ValueTable;
	Result.Columns.Add("Ref");
	Result.Columns.Add("Presentation", New TypeDescription("String"));
	Result.Columns.Add("Report", Metadata.Catalogs.ReportsOptions.Attributes.Report.Type);
	Result.Columns.Add("ReportByStringType", New TypeDescription("String"));
	Result.Columns.Add("Available", New TypeDescription("Boolean"));
	
	OptionsReferences = New Array;
	ConfigurationReportsReportsReferences = New Array;
	ExtensionsReportsReferences = New Array;
	AdditionalReportsReferences = New Array;
	
	SetPrivilegedMode(True);
	For Each Ref In ReportsReferences Do
		If Result.Find(Ref, "Ref") <> Undefined Then
			Continue;
		EndIf;
		TableRow = Result.Add();
		TableRow.Ref = Ref;
		TableRow.Presentation = String(Ref);
		Type = TypeOf(Ref);
		If Type = Type("CatalogRef.ReportsOptions") Then
			AddToArray(OptionsReferences, Ref);
		Else
			TableRow.Report = Ref;
			TableRow.ReportByStringType = ReportsOptionsClientServer.ReportByStringType(Type, TableRow.Report);
			If TableRow.ReportByStringType = "Internal" Then
				AddToArray(ConfigurationReportsReportsReferences, TableRow.Report);
			ElsIf TableRow.ReportByStringType = "Extension" Then
				AddToArray(ExtensionsReportsReferences, TableRow.Report);
			ElsIf TableRow.ReportByStringType = "Additional" Then
				AddToArray(AdditionalReportsReferences, TableRow.Report);
			EndIf;
		EndIf;
	EndDo;
	SetPrivilegedMode(False);
	
	If OptionsReferences.Count() > 0 Then
		ReportsValues = Common.ObjectsAttributeValue(OptionsReferences, "Report", True);
		For Each Ref In OptionsReferences Do
			TableRow = Result.Find(Ref, "Ref");
			ReportValue = ReportsValues[Ref];
			If ReportValue = Undefined Then
				TableRow.Presentation = NStr("ru = '<Недостаточно прав для работы с вариантом отчета>'; en = '<Insufficient rights to access the report option>'; pl = '<Niewystarczające uprawnienia do pracy z wariantem raportu>';es_ES = '<Insuficientes derechos para usar la variante del informe>';es_CO = '<Insuficientes derechos para usar la variante del informe>';tr = '<Rapor seçeneği ile çalışma hakları yetersiz>';it = '<Permessi insufficienti per accedere alla variante di report>';de = '<Unzureichende Rechte, um mit der Berichtsvariante zu arbeiten>'");
			Else
				TableRow.Report = ReportValue;
				TableRow.ReportByStringType = ReportsOptionsClientServer.ReportByStringType(Undefined, TableRow.Report);
				If TableRow.ReportByStringType = "Internal" Then
					AddToArray(ConfigurationReportsReportsReferences, TableRow.Report);
				ElsIf TableRow.ReportByStringType = "Extension" Then
					AddToArray(ExtensionsReportsReferences, TableRow.Report);
				ElsIf TableRow.ReportByStringType = "Additional" Then
					AddToArray(AdditionalReportsReferences, TableRow.Report);
				EndIf;
			EndIf;
		EndDo;
	EndIf;
	
	If ConfigurationReportsReportsReferences.Count() > 0 Then
		OnDetermineReportsAvailability(ConfigurationReportsReportsReferences, Result);
	EndIf;
	
	If ExtensionsReportsReferences.Count() > 0 Then
		OnDetermineReportsAvailability(ExtensionsReportsReferences, Result);
	EndIf;
	
	If AdditionalReportsReferences.Count() > 0 Then
		If Common.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
			ModuleAdditionalReportsAndDataProcessors = Common.CommonModule("AdditionalReportsAndDataProcessors");
			ModuleAdditionalReportsAndDataProcessors.OnDetermineReportsAvailability(AdditionalReportsReferences, Result);
		EndIf;
	EndIf;
	
	Return Result;
	
EndFunction

// Generates reference and report type by a full name.
//
// Parameters:
//   ReportFullName - String - the full name of the report in the following format:
//       "Report.<NameOfReport>" or "ExternalReport.<NameOfReport>".
//
// Returns:
//   Result - Structure -
//       * Report
//       * ReportType
//       * ReportName
//       * ReportMetadata
//       * ErrorText - String, Undefined - error text.
//
Function GenerateReportInformationByFullName(ReportFullName) Export
	Result = New Structure("Report, ReportType, ReportFullName, ReportName, ReportMetadata, ErrorText");
	Result.Report          = ReportFullName;
	Result.ReportFullName = ReportFullName;
	
	PointPosition = StrFind(ReportFullName, ".");
	If PointPosition = 0 Then
		Prefix = "";
		Result.ReportName = ReportFullName;
	Else
		Prefix = Left(ReportFullName, PointPosition - 1);
		Result.ReportName = Mid(ReportFullName, PointPosition + 1);
	EndIf;
	
	If Upper(Prefix) = "REPORT" Then
		Result.ReportMetadata = Metadata.Reports.Find(Result.ReportName);
		If Result.ReportMetadata = Undefined Then
			Result.ReportFullName = "ExternalReport." + Result.ReportName;
			WriteToLog(EventLogLevel.Warning,
				StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = 'Отчет ""%1"" не найден в программе, он будет значиться как внешний.'; en = 'Report ""%1"" is not found in the application, it will be marked as external.'; pl = 'W aplikacji nie znaleziono sprawozdania ""%1"", zostanie ono oznaczone jako zewnętrzne.';es_ES = 'Informe ""%1"" no se ha encontrado en la aplicación, se marcará como externo.';es_CO = 'Informe ""%1"" no se ha encontrado en la aplicación, se marcará como externo.';tr = 'Raporda ""%1"" bulunamıyor, harici olarak işaretlenecektir.';it = 'Report ""%1"" non trovato nel programma, verra registrato come uno esterno.';de = 'Der Report ""%1"" wurde in der Anwendung nicht gefunden, er wird als extern markiert.'"),
					ReportFullName));
		ElsIf Not AccessRight("View", Result.ReportMetadata) Then
			Result.ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Недостаточно прав доступа к отчету ""%1"".'; en = 'Insufficient access rights to report ""%1"".'; pl = 'Niewystarczające prawa dostępu do sprawozdania ""%1"".';es_ES = 'Insuficientes derechos de acceso para el informe ""%1"".';es_CO = 'Insuficientes derechos de acceso para el informe ""%1"".';tr = '""%1"" raporlamak için haklar yetersiz.';it = 'Diritti di accesso insufficienti al report ""%1"".';de = 'Unzureichende Zugriffsrechte zum Berichten von ""%1"".'"),
				ReportFullName);
		EndIf;
	ElsIf Upper(Prefix) = "EXTERNALREPORT" Then
		// It is not required to get metadata and perform checks.
	Else
		Result.ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Для отчета ""%1"" невозможно определить тип (не установлен префикс).'; en = 'Type cannot be defined for the ""%1"" report (prefix is not set).'; pl = 'Nie można określić typu sprawozdania ""%1"" (nie ustawiono prefiksu).';es_ES = 'Tipo no puede definirse para el informe ""%1"" (prefijo no está establecido).';es_CO = 'Tipo no puede definirse para el informe ""%1"" (prefijo no está establecido).';tr = '""%1"" Raporu için tür tanımlanamaz (önek ayarlanmamıştır).';it = 'Per il report ""%1"" impossibile definire la tipologia (prefisso non è installato).';de = 'Für den Bericht ""%1"" kann kein Typ definiert werden (Präfix ist nicht gesetzt).'"),
			ReportFullName);
		Return Result;
	EndIf;
	
	If Result.ReportMetadata = Undefined Then
		
		Result.Report = Result.ReportFullName;
		Result.ReportType = Enums.ReportTypes.External;
		
		// Replace a type and a reference of the external report for additional reports attached to the subsystem storage.
		If Common.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
			
			Result.Insert("ByDefaultAllConnectedToStorage", ByDefaultAllConnectedToStorage());
			ModuleAdditionalReportsAndDataProcessors = Common.CommonModule("AdditionalReportsAndDataProcessors");
			ModuleAdditionalReportsAndDataProcessors.OnDetermineTypeAndReferenceIfReportIsAuxiliary(Result);
			Result.Delete("ByDefaultAllConnectedToStorage");
			
			If TypeOf(Result.Report) <> Type("String") Then
				Result.ReportType = Enums.ReportTypes.Additional;
			EndIf;
			
		EndIf;
		
	Else
		
		Result.Report = Common.MetadataObjectID(Result.ReportMetadata);
		Result.ReportType = ReportsOptionsClientServer.ReportType(Result.Report);
		
	EndIf;
	
	Return Result;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// For a deployment report.

// Generates a tree of settings and predefined report options.
// Only for reports attached to the subsystem.
// After competing work with settings, you should call ReportsServer.ClearValuesTree to clear cyclic 
// references for correct clearing of memory .
//
// Returns:
//   ValueTree - settings of predefined report options attached to the subsystem.
//     
//     Attributes to change:
//       * Enabled              - Boolean - If False, the report option is not registered in the subsystem.
//       * DefaultVisibility - Boolean - if False, the report option is hidden from the report panel by default.
//       * Description         - String - a report option description.
//       * Details             - String - report option information.
//       * Placement           - Map - settings describing report option placement in sections.
//           ** Key - MetadataObject - a subsystem where a report or a report version is placed.
//           ** Value - String           - settings related to placement in a subsystem (group).
//               ""        - output a report in a subsystem without highlighting.
//               "Important"  - output a report in a subsystem marked in bold.
//               "SeeAlso" - output the report in the "See also" group.
//       * FunctionalOptions - Array of String - names of the report option functional options.
//       * SearchSettings  - Structure - additional settings related to the search of this report option.
//           You must configure these settings only in case DCS is not used or its functionality cannot be used completely.
//           For example, DCS can be used only for parametrization and receiving data whereas the 
//           output destination is a fixed template of a spreadsheet document.
//           ** FieldDescriptions - String - names of report option fields.
//           ** FilterAndParameterDescriptions - String - names of report option settings.
//           ** Keywords - String - Additional terminology (including specific or obsolete).
//           Term separator: Chars.LF.
//           ** TemplatesNames - String - the parameter is used instead of FieldDescriptions.
//               Names of spreadsheet or text document templates that are used to extract 
//               information on field descriptions.
//               Names are separated by commas.
//               Unfortunately, unlike DCS, templates do not contain information on links between 
//               fields and their presentations. Therefore it is recommended to fill in FieldDescriptions instead of 
//               TemplateNames for correct operating of the search engine.
//       * DCSSettingsFormat - Boolean - a report uses a standard settings storage format based on 
//           the DCS mechanics, and its main forms support the standard schema of interaction 
//           between forms (parameters and the type of the return values).
//           If False, then consistency checks and some components that require the standard format 
//           will be disabled for this report.
//       * DefineFormSettings - Boolean - a report has an interface for close integration with the 
//           report form. It can redefine some form settings and subscribe to its events.
//           If True and the report is attached to the general ReportForm form, then the procedure 
//           must be defined in the report object module according to the following template:
//               
//               // Define settings of the "Report options" subsystem common report form.
//               //
//               // Parameters:
//               //  Form - ClientApplicationForm, Undefined - a report form or a report settings form.
//               //      Undefined when called without a context.
//               //   VariantKey - String, Undefined -  a predefined report option name
//               //       or UUID of a custom one.
//               //      Undefined when called without a context.
//               //   Settings - Structure - see the return value of
//               //       ReportsClientServer.GetDefaultReportSettings().
//               //
//               Procedure DefineFormSettings(Form, VariantKey, Settings) Export
//               	// Procedure code.
//               EndProcedure
//     
//     Internal attributes (read-only):
//       * Report               - <see Catalogs.ReportOptions.Attributes.Report> - a full name or reference to a report.
//       * Metadata          - MetadataObject: Report - object metadata.
//       * OptionKey        - String - Report option name.
//       * DetailsReceived    - Boolean - shows whether the row details are already received.
//           Details are generated by the OptionDetails() method.
//       * SystemInfo - Structure - another internal information.
//
Function PredefinedItemsTree(FilterByReportsType = "Internal") Export
	CatalogAttributes = Metadata.Catalogs.ReportsOptions.Attributes;
	
	OptionsTree = New ValueTree;
	OptionsTree.Columns.Add("Report",                CatalogAttributes.Report.Type);
	OptionsTree.Columns.Add("Metadata",           New TypeDescription("MetadataObject"));
	OptionsTree.Columns.Add("UsesDCS",        New TypeDescription("Boolean"));
	OptionsTree.Columns.Add("VariantKey",         CatalogAttributes.VariantKey.Type);
	OptionsTree.Columns.Add("DetailsReceived",     New TypeDescription("Boolean"));
	OptionsTree.Columns.Add("Enabled",              New TypeDescription("Boolean"));
	OptionsTree.Columns.Add("VisibleByDefault", New TypeDescription("Boolean"));
	OptionsTree.Columns.Add("Description",         TypesDetailsString());
	OptionsTree.Columns.Add("Details",             TypesDetailsString());
	OptionsTree.Columns.Add("Placement",           New TypeDescription("Map"));
	OptionsTree.Columns.Add("SearchSettings",   New TypeDescription("Structure"));
	OptionsTree.Columns.Add("SystemInfo",  New TypeDescription("Structure"));
	OptionsTree.Columns.Add("Type",                  TypesDetailsString());
	OptionsTree.Columns.Add("IsOption",           New TypeDescription("Boolean"));
	OptionsTree.Columns.Add("FunctionalOptions",  New TypeDescription("Array"));
	OptionsTree.Columns.Add("GroupByReport", New TypeDescription("Boolean"));
	OptionsTree.Columns.Add("MeasurementsKey",          New TypeDescription("String"));
	OptionsTree.Columns.Add("MainOption");
	OptionsTree.Columns.Add("DCSSettingsFormat",        New TypeDescription("Boolean"));
	OptionsTree.Columns.Add("DefineFormSettings", New TypeDescription("Boolean"));
	
	GroupByReports = GlobalSettings().OutputReportsInsteadOfOptions;
	IndexingAllowed = SharedDataIndexingAllowed();
	HasAttachableCommands = Common.SubsystemExists("StandardSubsystems.AttachableCommands");
	If HasAttachableCommands Then
		AttachableReportsAndProcessorsComposition = Metadata.Subsystems["AttachableReportsAndDataProcessors"].Content;
		ModuleAttachableCommands = Common.CommonModule("AttachableCommands");
	EndIf;
	
	ReportsSubsystems = PlacingReportsToSubsystems();
	StorageFlagCache = Undefined;
	For Each ReportMetadata In Metadata.Reports Do
		If Not Common.SeparatedDataUsageAvailable() AND ReportMetadata.ConfigurationExtension() <> Undefined Then
			Continue;
		EndIf;
		
		If Not ReportAttachedToStorage(ReportMetadata, StorageFlagCache) Then
			Continue;
		EndIf;
		
		ReportRef = Common.MetadataObjectID(ReportMetadata);
		TypeOfReport = ReportsOptionsClientServer.ReportType(ReportRef, True);
		If FilterByReportsType <> Undefined AND FilterByReportsType <> TypeOfReport Then
			Continue;
		EndIf;
		
		HasAttributes = (ReportMetadata.Attributes.Count() > 0);
		
		// Settings.
		RowReport = OptionsTree.Rows.Add();
		RowReport.Report                = ReportRef;
		RowReport.Metadata           = ReportMetadata;
		RowReport.Enabled              = True;
		RowReport.VisibleByDefault = True;
		RowReport.Details             = ReportMetadata.Explanation;
		RowReport.Description         = ReportMetadata.Presentation();
		RowReport.DetailsReceived     = True;
		RowReport.Type                  = TypeOfReport;
		RowReport.IsOption           = False;
		RowReport.GroupByReport = GroupByReports;
		RowReport.UsesDCS        = (ReportMetadata.MainDataCompositionSchema <> Undefined);
		RowReport.DCSSettingsFormat    = RowReport.UsesDCS AND Not HasAttributes;
		
		// Subsystems.
		FoundItems = ReportsSubsystems.FindRows(New Structure("ReportMetadata", ReportMetadata));
		For Each RowSubsystem In FoundItems Do
			RowReport.Placement.Insert(RowSubsystem.SubsystemMetadata, "");
		EndDo;
		
		// Search.
		RowReport.SearchSettings = New Structure("FieldDescriptions, FilterParameterDescriptions, Keywords, TemplatesNames");
		
		// Predefined options.
		If RowReport.UsesDCS Then
			ReportManager = Reports[ReportMetadata.Name];
			DCSchema = Undefined;
			SettingsOptions = Undefined;
			Try
				DCSchema = ReportManager.GetTemplate(ReportMetadata.MainDataCompositionSchema.Name);
			Except
				ErrorText = NStr("ru = 'Не удалось прочитать схему отчета:'; en = 'Cannot read the report scheme:'; pl = 'Nie udało się odczytać schemat raportu:';es_ES = 'No se ha podido leer el esquema del informe:';es_CO = 'No se ha podido leer el esquema del informe:';tr = 'Rapor şeması okunamadı:';it = 'Impossibile leggere lo schema report:';de = 'Berichtslayout konnte nicht gelesen werden:'");
				ErrorText = ErrorText + Chars.LF + DetailErrorDescription(ErrorInfo());
				WriteToLog(EventLogLevel.Warning, ErrorText, ReportMetadata);
			EndTry;
			// Reading report option settings from the schema.
			If DCSchema <> Undefined Then
				Try
					SettingsOptions = DCSchema.SettingVariants;
				Except
					ErrorText = NStr("ru = 'Не удалось прочитать список вариантов отчета:'; en = 'Cannot read the report option list:'; pl = 'Nie udało się odczytać listy wariantów raportu:';es_ES = 'No se ha podido leer la lista de variantes del informe:';es_CO = 'No se ha podido leer la lista de variantes del informe:';tr = 'Rapor seçenekleri listesi okunamadı:';it = 'Non è possibile leggere l''elenco variante di report:';de = 'Liste der Berichtsoptionen konnte nicht gelesen werden:'");
					ErrorText = ErrorText + Chars.LF + DetailErrorDescription(ErrorInfo());
					WriteToLog(EventLogLevel.Warning, ErrorText, ReportMetadata);
				EndTry;
			EndIf;
			// Reading report option settings from the manager module (if cannot read from the schema).
			If SettingsOptions = Undefined Then
				Try
					SettingsOptions = ReportManager.SettingVariants();
				Except
					ErrorText = NStr("ru = 'Не удалось прочитать список вариантов отчета из модуля менеджера:'; en = 'Cannot read a report option list from the manager module:'; pl = 'Nie udało się odczytać listę wariantów raportu z modułu menedżera:';es_ES = 'No se ha podido leer la lista de variantes del informe del módulo del gerente:';es_CO = 'No se ha podido leer la lista de variantes del informe del módulo del gerente:';tr = 'Yönetici modülünden rapor seçeneklerinin bir listesi okunamıyor:';it = 'Non è stato possibile leggere l''elenco delle varianti di report dal modulo del manager:';de = 'Lesen der Liste der Berichtsoptionen aus dem Manager-Modul fehlgeschlagen:'");
					ErrorText = ErrorText + Chars.LF + DetailErrorDescription(ErrorInfo());
					WriteToLog(EventLogLevel.Error, ErrorText, ReportMetadata);
				EndTry;
			EndIf;
			// Found variant registration.
			If SettingsOptions <> Undefined Then
				For Each DCSettingsOption In SettingsOptions Do
					Option = RowReport.Rows.Add();
					Option.Report        = RowReport.Report;
					Option.VariantKey = DCSettingsOption.Name;
					Option.Description = DCSettingsOption.Presentation;
					Option.Type          = TypeOfReport;
					Option.IsOption   = True;
					If RowReport.MainOption = Undefined Then
						RowReport.MainOption = Option;
					EndIf;
					If IndexingAllowed AND TypeOf(DCSettingsOption) = Type("DataCompositionSettingsVariant") Then
						Try
							Option.SystemInfo.Insert("DCSettings", DCSettingsOption.Settings);
						Except
							ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
								NStr("ru = 'Не удалось прочитать настройки варианта ""%1"":'; en = 'Failed to read settings of the ""%1"" option:'; pl = 'Nie udało się odczytać ustawiania wariantu ""%1"":';es_ES = 'No se ha podido leer los ajustes del variante ""%1"":';es_CO = 'No se ha podido leer los ajustes del variante ""%1"":';tr = '""%1"" seçeneğine ait ayarlar okunamıyor:';it = 'Impossibile leggere le impostazioni della variante ""%1"":';de = 'Lesen der Einstellungsoptionen fehlgeschlagen ""%1"":'"),
								Option.VariantKey)
								+ Chars.LF
								+ DetailErrorDescription(ErrorInfo());
							WriteToLog(EventLogLevel.Warning, ErrorText, ReportMetadata);
						EndTry;
					EndIf;
				EndDo;
			EndIf;
		EndIf;
		
		// Report itself.
		If RowReport.MainOption = Undefined Then
			Option = RowReport.Rows.Add();
			FillPropertyValues(Option, RowReport, "Report, Description");
			Option.VariantKey = "";
			Option.IsOption   = True;
			RowReport.MainOption = Option;
		EndIf;
		
		// Processing reports included in the AttachableReportsAndDataProcessors subsystem.
		If HasAttachableCommands AND AttachableReportsAndProcessorsComposition.Contains(ReportMetadata) Then
			VenderSettings = ModuleAttachableCommands.AttachableObjectSettings(ReportMetadata.FullName());
			If VenderSettings.DefineFormSettings Then
				RowReport.DefineFormSettings = True;
			EndIf;
			If VenderSettings.CustomizeReportOptions Then
				CustomizeReportInManagerModule(OptionsTree, ReportMetadata);
			EndIf;
		EndIf;
	EndDo;
	
	// Extension functionality.
	If FilterByReportsType = Undefined Or FilterByReportsType = "Internal" Then
		CustomizeReportInManagerModule(OptionsTree, Metadata.Reports.UniversalReport);
		// Attachable handlers of the SL subsystems.
		SSLSubsystemsIntegration.OnSetUpReportsOptions(OptionsTree);
		// Overridable configuration module.
		ReportsOptionsOverridable.CustomizeReportsOptions(OptionsTree);
	EndIf;
	
	// Defining main options.
	For Each RowReport In OptionsTree.Rows Do
		If RowReport.GroupByReport = True Then
			If RowReport.MainOption = Undefined
				Or Not RowReport.MainOption.Enabled Then
				For Each Option In RowReport.Rows Do
					FillOptionRowDetails(Option, RowReport);
					If Option.Enabled Then
						RowReport.MainOption = Option;
						Option.VisibleByDefault = True;
						Break;
					EndIf;
				EndDo;
			EndIf;
		Else
			RowReport.MainOption = Undefined;
		EndIf;
	EndDo;
	
	Return OptionsTree;
EndFunction

// Defines whether a report is attached to the report option storage.
Function ReportAttachedToStorage(ReportMetadata, AllAttachedByDefault = Undefined) Export
	StorageMetadata = ReportMetadata.VariantsStorage;
	If StorageMetadata = Undefined Then
		If AllAttachedByDefault = Undefined Then
			AllAttachedByDefault = ByDefaultAllConnectedToStorage();
		EndIf;
		ReportAttached = AllAttachedByDefault;
	Else
		ReportAttached = (StorageMetadata = Metadata.SettingsStorages.ReportsVariantsStorage);
	EndIf;
	Return ReportAttached;
EndFunction

// Defines whether a report is attached to the common report form.
Function ReportAttachedToMainForm(ReportMetadata, AllAttachedByDefault = Undefined) Export
	MetadataForm = ReportMetadata.DefaultForm;
	If MetadataForm = Undefined Then
		If AllAttachedByDefault = Undefined Then
			AllAttachedByDefault = ByDefaultAllConnectedToMainForm();
		EndIf;
		ReportAttached = AllAttachedByDefault;
	Else
		ReportAttached = (MetadataForm = Metadata.CommonForms.ReportForm);
	EndIf;
	Return ReportAttached;
EndFunction

// Defines whether a report is attached to the common report settings form.
Function ReportAttachedToSettingsForm(ReportMetadata, AllAttachedByDefault = Undefined) Export
	MetadataForm = ReportMetadata.DefaultSettingsForm;
	If MetadataForm = Undefined Then
		If AllAttachedByDefault = Undefined Then
			AllAttachedByDefault = ByDefaultAllConnectedToSettingsForm();
		EndIf;
		ReportAttached = AllAttachedByDefault;
	Else
		ReportAttached = (MetadataForm = Metadata.CommonForms.ReportSettingsForm);
	EndIf;
	Return ReportAttached;
EndFunction

// List of objects where report commands are used.
//
// Returns:
//   Array from MetadataObject - metadata objects with report commands.
//
Function ObjectsWithReportCommands() Export
	
	Result = New Array;
	SSLSubsystemsIntegration.OnDefineObjectsWithReportCommands(Result);
	ReportsOptionsOverridable.DefineObjectsWithReportCommands(Result);
	Return Result;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Configuration subsystems event handlers.

// See InfobaseUpdateSSL.OnAddUpdateHandlers. 
Procedure OnAddUpdateHandlers(Handlers) Export
	
	////////////////////////////////////////////////////////////////////////////////
	// 1. Updating shared data.
	
	Handler = Handlers.Add();
	Handler.HandlerManagement = True;
	Handler.SharedData     = True;
	Handler.ExecutionMode = "Seamless";
	Handler.Version          = "*";
	Handler.Procedure       = "ReportsOptions.ConfigurationCommonDataNonexclusiveUpdate";
	Handler.Priority       = 90;
	
	////////////////////////////////////////////////////////////////////////////////
	// 2. Updating separated data.
	
	// 2.1. Migrate separated data to version 2.1.1.0.
	Handler = Handlers.Add();
	Handler.ExecuteInMandatoryGroup = True;
	Handler.SharedData     = False;
	Handler.ExecutionMode = "Exclusive";
	Handler.Version          = "2.1.1.0";
	Handler.Priority       = 80;
	Handler.Procedure       = "ReportsOptions.GoToEdition21";
	
	// 2.2. Migrate separated data to version 2.1.3.6.
	Handler = Handlers.Add();
	Handler.ExecuteInMandatoryGroup = True;
	Handler.SharedData     = False;
	Handler.ExecutionMode = "Exclusive";
	Handler.Version          = "2.1.3.6";
	Handler.Priority       = 80;
	Handler.Procedure       = "ReportsOptions.FillPredefinedOptionsRefs";
	
	// 2.3. Update separated data in local mode.
	Handler = Handlers.Add();
	Handler.ExecuteInMandatoryGroup = True;
	Handler.SharedData     = False;
	Handler.ExecutionMode = "Seamless";
	Handler.Version          = "*";
	Handler.Priority       = 70;
	Handler.Procedure       = "ReportsOptions.ConfigurationSharedDataNonexclusiveUpdate";
	
	////////////////////////////////////////////////////////////////////////////////
	// 3. Deferred update.
	
	// 3.1. Adjustment to Taxi interface.
	Handler = Handlers.Add();
	Handler.ExecutionMode = "Deferred";
	Handler.ID   = New UUID("814d41ec-82e2-4d25-9334-8335e589fc1f");
	Handler.SharedData     = False;
	Handler.Version          = "2.2.3.31";
	Handler.Procedure       = "ReportsOptions.NarrowDownQuickSettings";
	Handler.Comment     = NStr("ru = 'Уменьшает количество быстрых настроек в пользовательских отчетах до 2 шт.'; en = 'Reduces the number of quick settings in user-defined reports to 2.'; pl = 'Zmniejsza ilość szybkich ustawień w raportach użytkownika do 2 szt.';es_ES = 'Disminuye la cantidad de los ajustes rápidos en los informes de usuario hasta 2 unidades.';es_CO = 'Disminuye la cantidad de los ajustes rápidos en los informes de usuario hasta 2 unidades.';tr = 'Özel raporlardaki hızlı ayar sayısını 2 adete kadar azaltır.';it = 'Riduce a 2 il numero di impostazioni rapide nei report definiti dagli utenti.';de = 'Reduziert die Anzahl der Schnelleinstellungen in benutzerdefinierten Berichten auf 2.'");
	
	// 3.2. Fill in information to search for predefined report options.
	If SharedDataIndexingAllowed() Then
		Handler = Handlers.Add();
		If Common.DataSeparationEnabled() Then
			Handler.ExecutionMode = "Seamless";
			Handler.SharedData     = True;
		Else
			Handler.ExecutionMode = "Deferred";
			Handler.SharedData     = False; // It does not matter for the box, but if the value is True, the update mechanics raises an exception.
		EndIf;
		Handler.ID = New UUID("38d2a135-53e0-4c68-9bd6-3d6df9b9dcfb");
		Handler.Version        = "*";
		Handler.Procedure     = "ReportsOptions.ConfigurationSharedDataDeferredUpdateFull";
		Handler.Comment   = NStr("ru = 'Обновление индекса поиска отчетов, предусмотренных в программе.'; en = 'Update reports search index provided in the application.'; pl = 'Aktualizacja indeksu wyszukiwania raportów, przewidzianych w programie.';es_ES = 'Actualización del índice de la búsqueda de los informes predeterminados en el programa.';es_CO = 'Actualización del índice de la búsqueda de los informes predeterminados en el programa.';tr = 'Program tarafından sağlanan rapor arama dizini güncelleme.';it = 'Aggiorna l''indice di ricerca dei report fornito nell''applicazione.';de = 'Aktualisierung des Suchindexes der im Programm bereitgestellten Berichte.'");
	EndIf;
	
	// 3.3. Fill in information to search for user report options.
	Handler = Handlers.Add();
	Handler.ExecutionMode = "Deferred";
	Handler.SharedData     = False;
	Handler.ID   = New UUID("5ba93197-230b-4ac8-9abb-ab3662e5ff76");
	Handler.Version          = "*";
	Handler.Procedure       = "ReportsOptions.ConfigurationSeparatedDataDeferredUpdateFull";
	Handler.Comment     = NStr("ru = 'Обновление индекса поиска отчетов, сохраненных пользователями.'; en = 'Update search index of the reports saved by users.'; pl = 'Aktualizacja indeksu wyszukiwania raportów, zapisanych użytkownikiem.';es_ES = 'Actualización del índice de la búsqueda de los informes guardados por usuarios.';es_CO = 'Actualización del índice de la búsqueda de los informes guardados por usuarios.';tr = 'Kullanıcılar tarafından kaydedilen rapor arama dizini güncelleme.';it = 'Aggiorna indice di ricerca dei report salvati dagli utenti.';de = 'Aktualisierung des Suchindexes für Berichte, die von Benutzern gespeichert wurden.'");
	
	// 3.4. Set the corresponding references to metadata object IDs in settings of universal report options.
	Handler = Handlers.Add();
	Handler.Version = "3.0.1.81";
	Handler.ID = New UUID("6cd3c6c1-6919-4e18-9725-eb6dbb841f4a");
	Handler.ExecutionMode = "Deferred";
	Handler.DeferredProcessingQueue = 1;
	Handler.UpdateDataFillingProcedure = "Catalogs.ReportsOptions.RegisterDataToProcessForMigrationToNewVersion";
	Handler.Procedure = "Catalogs.ReportsOptions.ProcessDataForMigrationToNewVersion";
	Handler.ObjectsToRead = "Catalog.ReportsOptions";
	Handler.ObjectsToChange = "Catalog.ReportsOptions";
	Handler.ObjectsToLock = "Catalog.ReportsOptions";
	Handler.CheckProcedure = "InfobaseUpdate.DataUpdatedForNewApplicationVersion";
	Handler.Comment = NStr("ru = 'Установка параметра DataSource в настройках вариантов универсального отчета.
		|После завершения обработки, переименование объектов метаданных не приведет к потере сохраненных вариантов отчетов'; 
		|en = 'Set DataSource parameter in settings of universal report option.
		|Once the processing is completed, renaming of metadata objects will not result in loss of saved report options'; 
		|pl = 'Ustalenie DataSource parametru w ustawieniach wariantów raportu uniwersalnego.
		| Po zakończeniu przetwarzania, zmiana nazwy obiektów metadanych nie doprowadzi do utraty zapisanych wariantów raportów';
		|es_ES = 'Instalación del parámetro DataSource en los ajustes de las variantes del informe universal.
		|Al procesar, el cambio del nombre de los objetos de metadatos no llevará a la pérdida de las variantes guardadas del informe';
		|es_CO = 'Instalación del parámetro DataSource en los ajustes de las variantes del informe universal.
		|Al procesar, el cambio del nombre de los objetos de metadatos no llevará a la pérdida de las variantes guardadas del informe';
		|tr = 'Üniversal raporun seçeneklerinin ayarlarında DataSource parametresinin ayarı
		| İşleme tamamlandıktan sonra metaveri nesnelerin yeniden adlandırılması, kaydedilen raporların seçeneklerinin kaybına yol açmaz';
		|it = 'Imposta il parametro DataSource nelle impostazioni della variante report universale.
		|Una volta completata l''elaborazione, rinominare gli oggetti metadati non comporterà la perdita delle varianti del report salvato';
		|de = 'DataSource-Parameter in den Einstellungen der universellen Berichtsoption einstellen.
		|Nach Abschluss der Verarbeitung führt die Umbenennung von Metadatenobjekten nicht zum Verlust der gespeicherten Berichtsoptionen.'");

EndProcedure

// See CommonOverridable.OnAddRefsSearchExceptions. 
Procedure OnAddReferenceSearchExceptions(RefSearchExclusions) Export
	
	RefSearchExclusions.Add(Metadata.Catalogs.ReportsOptions.TabularSections.Placement.Attributes.Subsystem);
	
EndProcedure

// See CommonOverridable.OnAddMetadataObjectsRenaming. 
Procedure OnAddMetadataObjectsRenaming(Total) Export
	
	Library = "StandardSubsystems";
	
	Common.AddRenaming(
		Total, "2.1.0.2", "Role.ReadReportOptions", "Role.ReportOptionsUsage", Library);
	Common.AddRenaming(
		Total, "2.3.3.3", "Role.ReportOptionsUsage", "Role.AddEditPersonalReportsOptions", Library);
	
EndProcedure

// See ExportImportDataOverridable.OnFillCommonDataTypesSupportingReferenceComparisonOnImport. 
Procedure OnFillCommonDataTypesSupportingRefMappingOnExport(Types) Export
	
	Types.Add(Metadata.Catalogs.PredefinedReportsOptions);
	
EndProcedure

// See CommonOverridable.OnAddClientParametersOnStart. 
Procedure OnAddClientParametersOnStart(Parameters) Export
	Parameters.Insert("ReportsOptions", New FixedStructure(ClientParameters()));
EndProcedure

// See ExportImportDataOverridable.OnFillTypesExcludedFromExportImport. 
Procedure OnFillTypesExcludedFromExportImport(Types) Export
	
	Types.Add(Metadata.Catalogs.PredefinedExtensionsReportsOptions);
	Types.Add(Metadata.InformationRegisters.PredefinedExtensionsVersionsReportsOptions);
	
EndProcedure

// See ImportDataFromFileOverridable.OnDefineCatalogsForDataImport. 
Procedure OnDefineCatalogsForDataImport(CatalogsToImport) Export
	
	// Cannot import to the UserReportSettings catalog.
	TableRow = CatalogsToImport.Find(Metadata.Catalogs.UserReportSettings.FullName(), "FullName");
	If TableRow <> Undefined Then 
		CatalogsToImport.Delete(TableRow);
	EndIf;
	
EndProcedure

// See BatchObjectModificationOverridable.OnDetermineObjectsWithEditableAttributes. 
Procedure OnDefineObjectsWithEditableAttributes(Objects) Export
	Objects.Insert(Metadata.Catalogs.ReportsOptions.FullName(), "AttributesToEditInBatchProcessing");
	Objects.Insert(Metadata.Catalogs.UserReportSettings.FullName(), "AttributesToEditInBatchProcessing");
	Objects.Insert(Metadata.Catalogs.PredefinedReportsOptions.FullName(), "AttributesToEditInBatchProcessing");
	Objects.Insert(Metadata.Catalogs.PredefinedExtensionsReportsOptions.FullName(), "AttributesToEditInBatchProcessing");
EndProcedure

// See UsersOverridable.OnDefineRolesAssignment. 
Procedure OnDefineRoleAssignment(RolesAssignment) Export
	
	// BothForUsersAndExternalUsers.
	RolesAssignment.BothForUsersAndExternalUsers.Add(
		Metadata.Roles.AddEditPersonalReportsOptions.Name);
	
EndProcedure

// See InformationRegisters.ExtensionsVersionsParameters.FillAllExtensionParameters. 
Procedure OnFillAllExtensionsParameters() Export
	
	Settings = New Structure;
	Settings.Insert("Configuration",      False);
	Settings.Insert("Extensions",        True);
	
	Settings.Insert("SharedData",       True);
	Settings.Insert("SeparatedData", True);
	Settings.Insert("Nonexclusive",       True);
	Settings.Insert("Deferred",        True);
	Settings.Insert("Full",            True);
	
	Refresh(Settings);
	
EndProcedure

// См. InformationRegisters.ExtensionsVersionsParameters.ClearAllExtensionParameters. 
Procedure OnClearAllExtemsionParameters() Export
	
	RecordSet = InformationRegisters.PredefinedExtensionsVersionsReportsOptions.CreateRecordSet();
	RecordSet.Filter.ExtensionsVersion.Set(SessionParameters.ExtensionsVersion);
	RecordSet.Write();
	
EndProcedure

// See AttachableCommandsOverridable.OnDefineAttachableObjectsSettingsComposition. 
Procedure OnDefineAttachableObjectsSettingsComposition(InterfaceSettings) Export
	Setting = InterfaceSettings.Add();
	Setting.Key          = "AddReportCommands";
	Setting.TypeDescription = New TypeDescription("Boolean");
	
	Setting = InterfaceSettings.Add();
	Setting.Key          = "CustomizeReportOptions";
	Setting.TypeDescription = New TypeDescription("Boolean");
	Setting.AttachableObjectsKinds = "REPORT";
	
	Setting = InterfaceSettings.Add();
	Setting.Key          = "DefineFormSettings";
	Setting.TypeDescription = New TypeDescription("Boolean");
	Setting.AttachableObjectsKinds = "REPORT";
EndProcedure

// See AttachableCommandsOverridable.OnDefineAttachableCommandsKinds. 
Procedure OnDefineAttachableCommandsKinds(AttachableCommandsKinds) Export
	Kind = AttachableCommandsKinds.Add();
	Kind.Name         = "Reports";
	Kind.SubmenuName  = "ReportsSubmenu";
	Kind.Title   = NStr("ru = 'Отчеты'; en = 'Reports'; pl = 'Sprawozdania';es_ES = 'Informes';es_CO = 'Informes';tr = 'Raporlar';it = 'Reports';de = 'Berichte'");
	Kind.Order     = 50;
	Kind.Picture    = PictureLib.Report;
	Kind.Representation = ButtonRepresentation.PictureAndText;
EndProcedure

// See AttachableCommandsOverridable.OnDefineCommandsAttachedToObject. 
Procedure OnDefineCommandsAttachedToObject(FormSettings, Sources, AttachedReportsAndDataProcessors, Commands) Export
	ReportCommands = Commands.CopyColumns();
	ReportCommands.Columns.Add("VariantKey", New TypeDescription("String, Null"));
	ReportCommands.Columns.Add("Processed", New TypeDescription("Boolean"));
	ReportCommands.Indexes.Add("Processed");
	
	StandardProcessing = Sources.Rows.Count() > 0;
	FormSettings.Insert("Sources", Sources);
	
	SSLSubsystemsIntegration.BeforeAddReportCommands(ReportCommands, FormSettings, StandardProcessing);
	ReportsOptionsOverridable.BeforeAddReportCommands(ReportCommands, FormSettings, StandardProcessing);
	ReportCommands.FillValues(True, "Processed");
	If StandardProcessing Then
		ObjectsWithReportCommands = ObjectsWithReportCommands();
		For Each Source In Sources.Rows Do
			For Each DocumentRecorder In Source.Rows Do
				If ObjectsWithReportCommands.Find(DocumentRecorder.Metadata) <> Undefined Then
					OnAddReportsCommands(ReportCommands, DocumentRecorder, FormSettings);
				EndIf;
			EndDo;
			If ObjectsWithReportCommands.Find(Source.Metadata) <> Undefined Then
				OnAddReportsCommands(ReportCommands, Source, FormSettings);
			EndIf;
		EndDo;
	EndIf;
	
	FoundItems = AttachedReportsAndDataProcessors.FindRows(New Structure("AddReportCommands", True));
	For Each AttachedObject In FoundItems Do
		OnAddReportsCommands(ReportCommands, AttachedObject, FormSettings);
	EndDo;
	
	KeyCommandParametersNames = "ID,Presentation,FunctionalOptions,Manager,FormName,VariantKey,
	|FormParameterName,FormParameters,Handler,AdditionalParameters,VisibilityInForms";
	
	AddedCommands = New Map;
	
	For Each ReportsCommand In ReportCommands Do
		KeyParameters = New Structure(KeyCommandParametersNames);
		FillPropertyValues(KeyParameters, ReportsCommand);
		UUID = Common.CheckSumString(KeyParameters);
		
		FoundCommand = AddedCommands[UUID];
		If FoundCommand <> Undefined AND ValueIsFilled(FoundCommand.ParameterType) Then
			If ValueIsFilled(ReportsCommand.ParameterType) Then
				FoundCommand.ParameterType = New TypeDescription(FoundCommand.ParameterType, ReportsCommand.ParameterType.Types());
			Else
				FoundCommand.ParameterType = Undefined;
			EndIf;
			Continue;
		EndIf;
		
		Command = Commands.Add();
		AddedCommands.Insert(UUID, Command);
		
		FillPropertyValues(Command, ReportsCommand);
		Command.Kind = "Reports";
		If Command.Order = 0 Then
			Command.Order = 50;
		EndIf;
		If Command.WriteMode = "" Then
			Command.WriteMode = "WriteNewOnly";
		EndIf;
		If Command.MultipleChoice = Undefined Then
			Command.MultipleChoice = True;
		EndIf;
		If IsBlankString(Command.FormName) AND IsBlankString(Command.Handler) Then
			Command.FormName = "Form";
		EndIf;
		If Command.FormParameters = Undefined Then
			Command.FormParameters = New Structure;
		EndIf;
		Command.FormParameters.Insert("VariantKey", ReportsCommand.VariantKey);
		If IsBlankString(Command.Handler) Then
			Command.FormParameters.Insert("GenerateOnOpen", True);
			Command.FormParameters.Insert("ReportOptionsCommandsVisibility", False);
		EndIf;
	EndDo;
EndProcedure

// See AccessManagementOverridable.OnFillListsWithAccessRestriction. 
Procedure OnFillListsWithAccessRestriction(Lists) Export
	
	Lists.Insert(Metadata.Catalogs.ReportsOptions, True);
	Lists.Insert(Metadata.Catalogs.UserReportSettings, True);
	Lists.Insert(Metadata.InformationRegisters.ReportOptionsSettings, True);
	
EndProcedure

// See MonitoringCenterOverridable.OnCollectConfigurationStatisticsParameters. 
Procedure OnCollectConfigurationStatisticsParameters() Export
	
	If Not Common.SubsystemExists("StandardSubsystems.MonitoringCenter") Then
		Return;
	EndIf;
	
	ModuleMonitoringCenter = Common.CommonModule("MonitoringCenter");
	
	QueryText = 
	"SELECT
	|	COUNT(1) AS Count
	|FROM
	|	Catalog.ReportsOptions AS ReportsOptions
	|WHERE
	|	ReportsOptions.Custom";
	
	Query = New Query(QueryText);
	Selection = Query.Execute().Select();
	Selection.Next();
	
	ModuleMonitoringCenter.WriteConfigurationObjectStatistics("Catalog.ReportsOptions.Custom", Selection.Count());
	
EndProcedure

#EndRegion

#Region Private

// Initializing reports.

// The function gets the report object from the report option reference.
//
// Parameters:
//   RefOfReport -
//     - CatalogRef.MetadataObjectIDs - a configuration report reference.
//     - CatalogRef.ExtensionObjectIDs - an extension report reference.
//     - Arbitrary - a reference of an additional report or an external report.
//
// Returns:
//   Structure - report parameters including the report Object.
//       * Object      - ReportObject.<Report name>, ExternalReport - a report object.
//       * Name         - String           - a report object name.
//       * FullName   - String           - the full name of the report object.
//       * Metadata  - MetadataObject - a report metadata object.
//       * Ref      - Arbitrary     - a report reference.
//       * Success       - Boolean           - True if the report is attached.
//       * ErrorText - String           - an error text.
//
// Usage locations:
//   ReportMailing.InitReport().
//
Function AttachReportObject(RefOfReport, GetMetadata)
	Result = New Structure("Object, Name, FullName, Metadata, Ref, ErrorText");
	Result.Insert("Success", False);
	
	If RefOfReport = Undefined Then
		Result.ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'В методе ""%1"" не указан параметр ""%2"".'; en = 'Parameter ""%2"" is not specified in method ""%1"" .'; pl = 'W metodzie ""%1"" nie wskazano parametru ""%2"".';es_ES = 'En el método ""%1"" no está indicado el parámetro ""%2"".';es_CO = 'En el método ""%1"" no está indicado el parámetro ""%2"".';tr = '""%1"" yönteminde ""%2"" parametresi belirtilmedi.';it = 'Il parametro ""%2"" non è specificato nel metodo ""%1"".';de = 'Bei der Methode ""%1"" ist kein Parameter ""%2"" angegeben.'"),
			"AttachReportObject",
			"ReportRef");
		Return Result;
	Else
		Result.Ref = RefOfReport;
	EndIf;
	
	If TypeOf(Result.Ref) = Type("String") Then
		Result.ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Отчет ""%1"" записан как внешний и не может быть подключен из программы'; en = 'Report ""%1"" is written as external and cannot be attached from the application'; pl = 'Raport ""%1"" jest zapisany jako zewnętrzny i nie może być podłączony z aplikacji';es_ES = 'La variante ""%1"" se ha guardado como externa y no puede conectarse desde el programa';es_CO = 'La variante ""%1"" se ha guardado como externa y no puede conectarse desde el programa';tr = '""%1"" raporu harici olarak yazılır ve uygulamadan bağlanamaz';it = 'Il report ""%1"" è registrato come esterno e non può essere allegato dall''applicazione';de = 'Der Bericht ""%1"" ist als externer Bericht geschrieben und kann nicht von der Anwendung angehängt werden'"),
			Result.Ref);
		Return Result;
	EndIf;
	
	If TypeOf(Result.Ref) = Type("CatalogRef.MetadataObjectIDs")
	 Or TypeOf(Result.Ref) = Type("CatalogRef.ExtensionObjectIDs") Then
		
		Result.Metadata = Catalogs.MetadataObjectIDs.MetadataObjectByID(
			Result.Ref, True);
		
		If TypeOf(Result.Metadata) <> Type("MetadataObject") Then
			Result.ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Отчет ""%1"" не найден в программе'; en = 'Report ""%1"" is not found in the application'; pl = 'Nie znaleziono raportu ""%1"" w programie';es_ES = 'Informe ""%1"" no encontrado en el programa';es_CO = 'Informe ""%1"" no encontrado en el programa';tr = '""%1"" raporu uygulamada bulunamadı';it = 'Il report ""%1"" non è stato trovato nell''applicazione';de = 'Bericht ""%1"" wird im Programm nicht gefunden'"),
				Result.Name);
			Return Result;
		EndIf;
		Result.Name = Result.Metadata.Name;
		If Not AccessRight("Use", Result.Metadata) Then
			Result.ErrorText = NStr("ru = 'Недостаточно прав доступа'; en = 'Insufficient access rights'; pl = 'Brak praw dostępu!';es_ES = 'Insuficientes derechos de acceso';es_CO = 'Insuficientes derechos de acceso';tr = 'Yetersiz erişim yetkileri';it = 'Diritti di accesso insufficienti';de = 'Unzureichende Zugriffsrechte'");
			Return Result;
		EndIf;
		Try
			Result.Object = Reports[Result.Name].Create();
			Result.Success = True;
		Except
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Не удалось подключить отчет %1:'; en = 'Cannot attach the %1 report:'; pl = 'Nie można dołączyć raportu %1:';es_ES = 'No se ha podido conectar el informe %1:';es_CO = 'No se ha podido conectar el informe %1:';tr = '%1 raporu bağlanamadı:';it = 'Non è possibile allegare il report %1:';de = 'Der %1 Bericht kann nicht angehängt werden:'"),
				Result.Metadata);
			ErrorText = ErrorText + Chars.LF + DetailErrorDescription(ErrorInfo());
			WriteToLog(EventLogLevel.Error, ErrorText, Result.Metadata);
		EndTry;
	Else
		If Common.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
			ModuleAdditionalReportsAndDataProcessors = Common.CommonModule("AdditionalReportsAndDataProcessors");
			ModuleAdditionalReportsAndDataProcessors.OnAttachAdditionalReport(Result.Ref, Result, Result.Success, GetMetadata);
		EndIf;
	EndIf;
	
	If Result.Success AND GetMetadata Then
		Result.FullName = Result.Metadata.FullName();
	EndIf;
	
	Return Result;
EndFunction

// Data composition.

// Generates a report with the specified settings. Used in background jobs.
Procedure GenerateReportInBackground(Parameters, StorageAddress) Export
	Generation = GenerateReport(Parameters, False, False);
	
	Result = New Structure("SpreadsheetDocument, Details,
		|Success, ErrorText, DataStillUpdating,
		|VariantModified, UserSettingsModified");
	FillPropertyValues(Result, Generation);
	
	If Result.VariantModified Then
		Result.Insert("DCSettings", Generation.DCSettings);
	EndIf;
	If Result.UserSettingsModified Then
		Result.Insert("DCUserSettings", Generation.DCUserSettings);
	EndIf;
	
	PutToTempStorage(Result, StorageAddress);
EndProcedure

// Fills in settings description for a report option row if it is not filled in.
//
// Parameters:
//   OptionRow - TreeRow - a description of report option settings.
//   ReportRow   - TreeRow - Optional. Report settings description.
//
Procedure FillOptionRowDetails(RowOption, RowReport = Undefined) Export
	If RowOption.DetailsReceived Then
		Return;
	EndIf;
	
	If RowReport = Undefined Then
		RowReport = RowOption.Parent;
	EndIf;
	
	// Flag indicating whether the settings changed
	RowOption.DetailsReceived = True;
	
	// Copying report settings.
	FillPropertyValues(RowOption, RowReport, "Enabled, VisibleByDefault, GroupByReport");
	
	If RowOption = RowReport.MainOption Then
		// Default option.
		RowOption.Details = RowReport.Details;
		RowOption.VisibleByDefault = True;
	Else
		// Predefined option.
		If RowOption.GroupByReport Then
			RowOption.VisibleByDefault = False;
		EndIf;
	EndIf;
	
	RowOption.Placement = CommonClientServer.CopyMap(RowReport.Placement);
	RowOption.FunctionalOptions = CommonClientServer.CopyArray(RowReport.FunctionalOptions);
	RowOption.SearchSettings = CommonClientServer.CopyStructure(RowReport.SearchSettings);
	RowOption.MeasurementsKey = Common.TrimStringUsingChecksum("Report." + RowReport.Metadata.Name 
		+ "." + RowOption.VariantKey, 135);
	
EndProcedure

// Report panels.

// Generates a list of sections where the report panel calling commands are available.
//
// Returns:
//   ValueList - See description 1 of the ReportOptionsOverridable.DefineSectionsWithReportOptions() procedure parameter.
//
Function SectionsList() Export
	SectionsList = New ValueList;
	
	ReportsOptionsOverridable.DefineSectionsWithReportOptions(SectionsList);
	
	If Common.SubsystemExists("StandardSubsystems.ApplicationSettings") Then
		ModuleDataProcessorsControlPanelSSL = Common.CommonModule("DataProcessors.SSLAdministrationPanel");
		ModuleDataProcessorsControlPanelSSL.OnDefineSectionsWithReportOptions(SectionsList);
	EndIf;
	
	Return SectionsList;
EndFunction

// Sets output mode for report options in report panels.
//
// Parameters:
//   OptionTree - ValueTree - the parameter is passed as is from the SetUpReportsOptions procedure.
//   Report - ValueTreeRow, MetadataObject: Report - a settings description or report metadata.
//   GroupByReports - Boolean - the output mode in the report panel:
//       - True - by reports (options are hidden, and a report is enabled and visible).
//       - False - by options (options are visible; a report is disabled).
//
Procedure SetReportOutputModeInReportsPanels(OptionsTree, Report, GroupByReports)
	If TypeOf(Report) = Type("ValueTreeRow") Then
		RowReport = Report;
	Else
		RowReport = OptionsTree.Rows.Find(Report, "Metadata", False);
		If RowReport = Undefined Then
			WriteToLog(EventLogLevel.Warning, 
				StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = 'Отчет ""%1"" не подключен к подсистеме.'; en = 'Report ""%1"" is not attached to the subsystem.'; pl = 'Sprawozdanie ""%1"" nie jest połączone z podsystemem.';es_ES = 'Informe ""%1"" no se ha adjuntado al subsistema.';es_CO = 'Informe ""%1"" no se ha adjuntado al subsistema.';tr = 'Rapor ""%1"" alt sisteme bağlı değil.';it = 'Il report ""%1"" non è connesso al sottosistema.';de = 'Der Bericht ""%1"" ist nicht an das Subsystem angehängt.'"), Report.Name));
			Return;
		EndIf;
	EndIf;
	RowReport.GroupByReport = GroupByReports;
EndProcedure

// Generates a table of replacements of old option keys for relevant ones.
//
// Returns:
//   ValueTable - Table of option name changes. Columns:
//       * ReportMetadata - MetadataObject: Report - metadata of the report whose schema contains the changed option name.
//       * OldOptionName - String - the old option name before changes.
//       * RelevantOptionName - String - The current (last relevant) option name.
//       * Report - CatalogRef.MetadataObjectIDs, String - a reference or a report name used for 
//           storage.
//
// See also:
//   ReportOptionsOverridable.RegisterChangesOfReportOptionsKeys().
//
Function KeysChanges()
	
	OptionsAttributes = Metadata.Catalogs.ReportsOptions.Attributes;
	
	Changes = New ValueTable;
	Changes.Columns.Add("Report",                 New TypeDescription("MetadataObject"));
	Changes.Columns.Add("OldOptionName",     OptionsAttributes.VariantKey.Type);
	Changes.Columns.Add("RelevantOptionName", OptionsAttributes.VariantKey.Type);
	
	// Overridable part.
	ReportsOptionsOverridable.RegisterChangesOfReportOptionsKeys(Changes);
	
	Changes.Columns.Report.Name = "ReportMetadata";
	Changes.Columns.Add("Report", OptionsAttributes.Report.Type);
	
	// Check replacements for correctness.
	For Each Update In Changes Do
		Update.Report = Common.MetadataObjectID(Update.ReportMetadata);
		FoundItems = Changes.FindRows(New Structure("ReportMetadata, OldOptionName", Update.ReportMetadata, Update.RelevantOptionName));
		If FoundItems.Count() > 0 Then
			Conflict = FoundItems[0];
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Ошибка регистрации изменений имени варианта отчета ""%1"":
				|Актуальное имя варианта ""%2"" (старое имя ""%3"")
				|также числится как старое имя ""%4"" (актуальное имя ""%5"").'; 
				|en = 'An error occurred when registering a name change of the ""%1"" report option:
				|Current option name ""%2"" (previous name is ""%3"") 
				|is also considered as a previous name ""%4"" (the current name is ""%5"").'; 
				|pl = 'Błąd rejestracji zmian imienia wariantu raportu ""%1"":
				|Aktualna nazwa wariantu ""%2"" (stara nazwa ""%3"")
				|także liczy się jako stara nazwa ""%4"" (aktualna nazwa ""%5"").';
				|es_ES = 'Ha ocurrido un error al registrar los cambios del nombre de la variante del informe ""%1"":
				|Nombre de la variante actual ""%2"" (nombre antiguo ""%3"")
				|es también un nombre antiguo ""%4"" (nombre actual ""%5"").';
				|es_CO = 'Ha ocurrido un error al registrar los cambios del nombre de la variante del informe ""%1"":
				|Nombre de la variante actual ""%2"" (nombre antiguo ""%3"")
				|es también un nombre antiguo ""%4"" (nombre actual ""%5"").';
				|tr = '""%1"" rapor seçeneği için ad değişikliği kaydedilirken hata oluştu:
				|Mevcut seçenek adı ""%2"" (önceki adı ""%3"") da
				|önceki ad ""%4"" (mevcut adı ""%5"") olarak değerlendiriliyor.';
				|it = 'Si è verificato un errore durante la registrazione del nome della variante ""%1"" del report:
				|Il nome corrente è ""%2"" (il nome precedente è ""%3"") 
				|è anche considerato come nome precedente ""%4"" (il nome attuale è ""%5"").';
				|de = 'Fehler bei der Registrierung des Namens der Berichtsvariante ""%1"":
				|Der aktuelle Name der Variante ""%2"" (alter Name ""%3"")
				|wird auch als alter Name ""%4"" (aktueller Name ""%5"") aufgeführt.'"),
				String(Update.Report),
				Update.RelevantOptionName,
				Update.OldOptionName,
				Conflict.OldOptionName,
				Conflict.RelevantOptionName);
		EndIf;
		FoundItems = Changes.FindRows(New Structure("ReportMetadata, OldOptionName", Update.ReportMetadata, Update.OldOptionName));
		If FoundItems.Count() > 2 Then
			Conflict = FoundItems[1];
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Ошибка регистрации изменений имени варианта отчета ""%1"":
				|Старое имя варианта ""%2"" (актуальное имя ""%3"")
				|также числится как старое имя 
				|варианта отчета ""%4"" (актуальное имя ""%5"").'; 
				|en = 'An error occurred when registering a name change for the ""%1"" report option:
				|Previous option name ""%2"" (the current name is ""%3"") 
				|is also considered as a previous 
				|report option name ""%4"" (the current name is ""%5"").'; 
				|pl = 'Błąd rejestracji zmian imienia wariantu raportu ""%1"":
				|Stara nazwa wariantu ""%2"" (aktualna nazwa ""%3"")
				|także liczy się jako stara nazwa 
				|wariantu raportu ""%4"" (aktualna nazwa ""%5"").';
				|es_ES = 'Ha ocurrido un error al registrar el nombre de la variante del informe ""%1"":
				|Nombre de la variante antiguo ""%2"" (nombre actual ""%3"")
				|está en la lista como un nombre de 
				|la variante del informe antiguo ""%4"" (nombre relevante ""%5"").';
				|es_CO = 'Ha ocurrido un error al registrar el nombre de la variante del informe ""%1"":
				|Nombre de la variante antiguo ""%2"" (nombre actual ""%3"")
				|está en la lista como un nombre de 
				|la variante del informe antiguo ""%4"" (nombre relevante ""%5"").';
				|tr = '""%1"" rapor seçeneği için ad değişikliği kaydedilirken hata oluştu:
				|Önceki seçenek adı ""%2"" (mevcut adı ""%3"") da
				|önceki rapor seçeneği adı ""%4"" (mevcut adı ""%5"")
				|olarak değerlendiriliyor.';
				|it = 'Si è verificato un errore durante la registrazione del nome modificato della variante ""%1"" del report:
				|Il nome precedente della variante è ""%2"" (il nome attuale è ""%3"") 
				|""%4"" è anche considerato come nome precedente 
				|della variante (il nome attuale è ""%5"").';
				|de = 'Fehler bei der Registrierung des Namens der Berichtsvariante ""%1"":
				|Der alte Name der Variante ""%2"" (aktueller Name ""%3"")
				|wird auch als alter Name
				|der Berichtsvariante ""%4"" (aktueller Name ""%5"") aufgeführt.'"),
				String(Update.Report),
				Update.OldOptionName,
				Update.RelevantOptionName,
				String(Conflict.ReportMetadata.Presentation()),
				Conflict.RelevantOptionName);
		EndIf;
	EndDo;
	
	Return Changes;
EndFunction

// Generates a table of report placement by configuration subsystems.
//
// Parameters:
//   Result          - Undefined - used for recursion.
//   SubsystemParent - Undefined - used for recursion.
//
// Returns:
//   Результат - ValueTable - Settings of report placement to subsystems.
//       * ReportMetadata      - MetadataObject: Report.
//       * ReportFullName       - String.
//       * SubsystemMetadata - MetadataObject: Subsystem.
//       * SubsystemFullName  - String.
//
Function PlacingReportsToSubsystems(Result = Undefined, SubsystemParent = Undefined)
	If Result = Undefined Then
		FullNameTypesDetails = Metadata.Catalogs.MetadataObjectIDs.Attributes.FullName.Type;
		
		Result = New ValueTable;
		Result.Columns.Add("ReportMetadata",      New TypeDescription("MetadataObject"));
		Result.Columns.Add("ReportFullName",       FullNameTypesDetails);
		Result.Columns.Add("SubsystemMetadata", New TypeDescription("MetadataObject"));
		Result.Columns.Add("SubsystemFullName",  FullNameTypesDetails);
		
		Result.Indexes.Add("ReportFullName");
		
		SubsystemParent = Metadata;
	EndIf;
	
	// Iterating nested parent subsystems.
	For Each SubsystemMetadata In SubsystemParent.Subsystems Do
		
		If SubsystemMetadata.IncludeInCommandInterface Then
			For Each ReportMetadata In SubsystemMetadata.Content Do
				If Not Metadata.Reports.Contains(ReportMetadata) Then
					Continue;
				EndIf;
				
				TableRow = Result.Add();
				TableRow.ReportMetadata      = ReportMetadata;
				TableRow.ReportFullName       = ReportMetadata.FullName();
				TableRow.SubsystemMetadata = SubsystemMetadata;
				TableRow.SubsystemFullName  = SubsystemMetadata.FullName();
				
			EndDo;
		EndIf;
		
		PlacingReportsToSubsystems(Result, SubsystemMetadata);
	EndDo;
	
	Return Result;
EndFunction

// Resetting the "Report options" predefined item settings connected to the "Report options" catalog 
//   item.
//
// Parameters:
//   OptionObject - CatalogObject.ReportOptions, FormDataStructure - a report option.
//
Function ResetReportOptionSettings(OptionObject) Export
	If OptionObject.Custom
		Or (OptionObject.ReportType <> Enums.ReportTypes.Internal
			AND OptionObject.ReportType <> Enums.ReportTypes.Extension)
		Or Not ValueIsFilled(OptionObject.PredefinedVariant) Then
		Return False;
	EndIf;
	
	OptionObject.Author = Undefined;
	OptionObject.AvailableToAuthorOnly = False;
	OptionObject.Details = "";
	OptionObject.Placement.Clear();
	OptionObject.DefaultVisibilityOverridden = False;
	Predefined = Common.ObjectAttributesValues(
		OptionObject.PredefinedVariant,
		"Description, VisibleByDefault");
	FillPropertyValues(OptionObject, Predefined);
	
	Return True;
EndFunction

// Generates description of the String types of the specified length.
Function TypesDetailsString(StringLength = 1000) Export
	Return New TypeDescription("String", , New StringQualifiers(StringLength));
EndFunction

// It defines full rights to subsystem data by role composition.
Function FullRightsToOptions() Export
	
	AccessParameters = AccessParameters("Update", Metadata.Catalogs.ReportsOptions, 
		Metadata.Catalogs.ReportsOptions.StandardAttributes.Ref.Name);
	Return AccessParameters.Accessibility AND Not AccessParameters.RestrictionByCondition;
	
EndFunction

// Checks whether a report option name is not occupied.
Function DescriptionIsUsed(Report, Ref, Description) Export
	If Description = Common.ObjectAttributeValue(Ref, "Description") Then
		Return False; // Check is disabled as the name did not change.
	EndIf;
	
	Query = New Query;
	Query.Text = 
	"SELECT TOP 1
	|	1 AS DescriptionIsUsed
	|FROM
	|	Catalog.ReportsOptions AS ReportsOptions
	|WHERE
	|	ReportsOptions.Report = &Report
	|	AND ReportsOptions.Ref <> &Ref
	|	AND ReportsOptions.Description = &Description
	|	AND ReportsOptions.DeletionMark = FALSE
	|	AND NOT ReportsOptions.PredefinedVariant IN (&DIsabledApplicationOptions)";
	Query.SetParameter("Report",        Report);
	Query.SetParameter("Ref",       Ref);
	Query.SetParameter("Description", Description);
	Query.SetParameter("DIsabledApplicationOptions", ReportsOptionsCached.DIsabledApplicationOptions());
	
	SetPrivilegedMode(True);
	Result = Not Query.Execute().IsEmpty();
	SetPrivilegedMode(False);
	
	Return Result;
EndFunction

// Checks whether a report option key is not occupied.
Function OptionKeyIsUsed(Report, Ref, OptionKey) Export
	Query = New Query;
	Query.Text = 
	"SELECT TOP 1
	|	1 AS OptionKeyIsUsed
	|FROM
	|	Catalog.ReportsOptions AS ReportsOptions
	|WHERE
	|	ReportsOptions.Report = &Report
	|	AND ReportsOptions.Ref <> &Ref
	|	AND ReportsOptions.VariantKey = &VariantKey
	|	AND ReportsOptions.DeletionMark = FALSE";
	Query.SetParameter("Report",        Report);
	Query.SetParameter("Ref",       Ref);
	Query.SetParameter("VariantKey", OptionKey);
	
	SetPrivilegedMode(True);
	Result = Not Query.Execute().IsEmpty();
	SetPrivilegedMode(False);
	
	Return Result;
EndFunction

// Creates a filter by the ObjectKey attribute for StandardSettingsStorageManager.Select().
Function NewFilterByObjectKey(ReportsNames)
	If ReportsNames = "" Or ReportsNames = "*" Then
		Return Undefined;
	EndIf;
	
	SeparatorPosition = StrFind(ReportsNames, ",");
	If SeparatorPosition = 0 Then
		ObjectKey = ReportsNames;
		ReportsNames = "";
	Else
		ObjectKey = TrimAll(Left(ReportsNames, SeparatorPosition - 1));
		ReportsNames = Mid(ReportsNames, SeparatorPosition + 1);
	EndIf;
	
	If StrFind(ObjectKey, ".") = 0 Then
		ObjectKey = "Report." + ObjectKey;
	EndIf;
	
	Return New Structure("ObjectKey", ObjectKey);
EndFunction

// Global subsystem settings.
Function GlobalSettings() Export
	Result = New Structure;
	Result.Insert("OutputReportsInsteadOfOptions", False);
	Result.Insert("OutputDetails",              True);
	Result.Insert("EditOptionsAllowed",     True);
	
	Result.Insert("Search", New Structure);
	Result.Search.Insert("InputHint", NStr("ru = 'Наименование, поле или автор отчета'; en = 'Name, field or author of the report'; pl = 'Nazwa, pole lub autor raportu';es_ES = 'El nombre, el campo o el autor del informe';es_CO = 'El nombre, el campo o el autor del informe';tr = 'Raporun adı, alanı veya yazarı';it = 'Nome, campo o autore del report';de = 'Name, Feld oder Autor des Berichts'"));
	
	Result.Insert("OtherReports", New Structure);
	Result.OtherReports.Insert("CloseAfterChoice", True);
	Result.OtherReports.Insert("ShowCheckBox", False);
	
	ReportsOptionsOverridable.OnDefineSettings(Result);
	
	Return Result;
EndFunction

// Global settings of a report panel.
Function CommonPanelSettings() Export
	CommonSettings = Common.CommonSettingsStorageLoad(
		ReportsOptionsClientServer.FullSubsystemName(),
		"ReportPanel");
	If CommonSettings = Undefined Then
		CommonSettings = New Structure("ShowTooltips, SearchInAllSections, ShowTooltipsNotification");
		CommonSettings.ShowTooltipsNotification = False;
		CommonSettings.ShowTooltips           = GlobalSettings().OutputDetails;
		CommonSettings.SearchInAllSections          = False;
	Else
		// A feature can be considered new for a user only if a user has an understanding of what “old” 
		// features are (that is, if he has already worked with this form).
		If Not CommonSettings.Property("ShowTooltipsNotification") Then
			CommonSettings.Insert("ShowTooltipsNotification", True);
		EndIf;
	EndIf;
	Return CommonSettings;
EndFunction

// Global settings of a report panel.
Function SaveCommonPanelSettings(CommonSettings) Export
	If TypeOf(CommonSettings) <> Type("Structure") Then
		Return Undefined;
	EndIf;
	If CommonSettings.Count() < 3 Then
		CommonClientServer.SupplementStructure(CommonSettings, CommonPanelSettings(), False);
	EndIf;
	Common.CommonSettingsStorageSave(
		ReportsOptionsClientServer.FullSubsystemName(),
		"ReportPanel",
		CommonSettings);
	Return CommonSettings;
EndFunction

// Global client settings of a report.
Function ClientParameters() Export
	ClientParameters = New Structure;
	ClientParameters.Insert("RunMeasurements", RunMeasurements());
	If ClientParameters.RunMeasurements Then
		SetPrivilegedMode(True);
		ClientParameters.Insert("MeasurementsPrefix", StrReplace(SessionParameters["TimeMeasurementComment"], ";", "; "));
	EndIf;
	
	Return ClientParameters;
EndFunction

// Global client settings of a report.
Function RunMeasurements()
	If SafeMode() <> False Then
		Return False;
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.PerformanceMonitor") Then
		ModulePerformanceMonitorServerCallCached = Common.CommonModule("PerformanceMonitorServerCallCached");
		If ModulePerformanceMonitorServerCallCached.RunPerformanceMeasurements() Then
			Return True;
		EndIf;
	EndIf;
	
	Return False;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Event log

// Record to the event log.
Procedure WriteToLog(Level, Message, ReportOption = Undefined) Export
	If TypeOf(ReportOption) = Type("MetadataObject") Then
		MetadataObject = ReportOption;
		Data = MetadataObject.Presentation();
	Else
		MetadataObject = Metadata.Catalogs.ReportsOptions;
		Data = ReportOption;
	EndIf;
	WriteLogEvent(ReportsOptionsClientServer.SubsystemDescription(Undefined),
		Level, MetadataObject, Data, Message);
EndProcedure

// Writes a procedure start event to the event log.
Procedure WriteProcedureStartToLog(ProcedureName)
	
	WriteLogEvent(ReportsOptionsClientServer.SubsystemDescription(Undefined),
		EventLogLevel.Information,,,
		StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Запуск процедуры ""%1"".'; en = 'Starting %1.'; pl = 'Rozpocząć procedurę ""%1"".';es_ES = 'Iniciar el procedimiento ""%1"".';es_CO = 'Iniciar el procedimiento ""%1"".';tr = '""%1"" Prosedürünü başlatın.';it = 'Inizio %1.';de = 'Starten Sie das ""%1"" Verfahren.'"), ProcedureName)); 
		
EndProcedure

// Writes a procedure completion event to the event log.
Procedure WriteProcedureCompletionToLog(ProcedureName, ObjectsChanged = Undefined)
	
	Text = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Завершение процедуры ""%1"".'; en = 'Finish procedure ""%1"".'; pl = 'Zakończyć procedurę ""%1"".';es_ES = 'Finalizar el procedimiento ""%1"".';es_CO = 'Finalizar el procedimiento ""%1"".';tr = '""%1"" prosedürün sonu.';it = 'Completamento procedura ""%1"".';de = 'Beenden Sie das Verfahren ""%1"".'"), ProcedureName);
	If ObjectsChanged <> Undefined Then
		Text = Text + " " 
			+ StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Изменено %1 объектов.'; en = '%1 objects are changed.'; pl = 'Zmieniono %1 obiektów.';es_ES = 'Cambiado %1 objetos.';es_CO = 'Cambiado %1 objetos.';tr = '%1 nesne değiştirildi.';it = '%1 oggetti sono modificati';de = 'Geänderte %1 Objekte.'"), ObjectsChanged);
	EndIf;
	WriteLogEvent(ReportsOptionsClientServer.SubsystemDescription(Undefined),
		EventLogLevel.Information, , , Text);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Standard event handlers.

// Deleting personal report options upon user deletion.
Procedure OnRemoveUser(UserObject, Cancel) Export
	If UserObject.IsNew()
		Or UserObject.DataExchange.Load
		Or Cancel
		Or Not UserObject.DeletionMark Then
		Return;
	EndIf;
	
	// Set a deletion mark of personal user options.
	QueryText =
	"SELECT
	|	ReportsOptions.Ref
	|FROM
	|	Catalog.ReportsOptions AS ReportsOptions
	|WHERE
	|	ReportsOptions.Author = &UserRef
	|	AND ReportsOptions.DeletionMark = FALSE
	|	AND ReportsOptions.AvailableToAuthorOnly = TRUE";
	
	Query = New Query;
	Query.SetParameter("UserRef", UserObject.Ref);
	Query.Text = QueryText;
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		OptionObject = Selection.Ref.GetObject();
		OptionObject.AdditionalProperties.Insert("IndexSchema", False);
		OptionObject.SetDeletionMark(True);
	EndDo;
EndProcedure

// Delete subsystems references before their deletion.
Procedure BeforeDeleteMetadataObjectID(MetadataObjectIDObject, Cancel) Export
	If MetadataObjectIDObject.DataExchange.Load Then
		Return;
	EndIf;
	
	Subsystem = MetadataObjectIDObject.Ref;
	
	QueryText =
	"SELECT DISTINCT
	|	ReportsOptions.Ref
	|FROM
	|	Catalog.ReportsOptions AS ReportsOptions
	|WHERE
	|	ReportsOptions.Placement.Subsystem = &Subsystem";
	
	Query = New Query;
	Query.SetParameter("Subsystem", Subsystem);
	Query.Text = QueryText;
	
	OptionsToAssign = Query.Execute().Unload().UnloadColumn("Ref");
	
	BeginTransaction();
	Try
		Lock = New DataLock;
		For Each OptionRef In OptionsToAssign Do
			LockItem = Lock.Add(Metadata.Catalogs.ReportsOptions.FullName());
			LockItem.SetValue("Ref", OptionRef);
		EndDo;
		Lock.Lock();
		
		For Each OptionRef In OptionsToAssign Do
			OptionObject = OptionRef.GetObject();
			
			FoundItems = OptionObject.Placement.FindRows(New Structure("Subsystem", Subsystem));
			For Each TableRow In FoundItems Do
				OptionObject.Placement.Delete(TableRow);
			EndDo;
			
			OptionObject.Write();
		EndDo;
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Updating an infobase.

// [*] Updates cache of configuration metadata: the PredefinedReportOptions catalog and report 
//     option parameters in the register.
Procedure ConfigurationCommonDataNonexclusiveUpdate(UpdateParameters) Export
	
	CommonDataNonexclusiveUpdate("ConfigurationCommonData", UpdateParameters.SeparatedHandlers);
	
EndProcedure

// [*] Updates data of the ReportsOptions catalog in some configuration reports.
Procedure ConfigurationSharedDataNonexclusiveUpdate() Export
	
	SeparatedDataNonexclusiveUpdate("SeparatedConfigurationData");
	
EndProcedure

// Full update of the search index of predefined report options.
Procedure ConfigurationSharedDataDeferredUpdateFull(Parameters = Undefined) Export
	
	DeferredDataUpdate("ConfigurationCommonData", True);
	
EndProcedure

// Full update of the report option search index.
Procedure ConfigurationSeparatedDataDeferredUpdateFull(Parameters = Undefined) Export
	
	DeferredDataUpdate("SeparatedConfigurationData", True);
	
EndProcedure

// [2.1.1.1] Transfers data of the "Report options" catalog for revision 2.1.
Procedure GoToEdition21() Export
	ProcedurePresentation = NStr("ru = 'Перейти к редакции 2.1'; en = 'Go to edition 2.1'; pl = 'Przejdź do edycji 2.1';es_ES = 'Pasar a la redacción 2.1';es_CO = 'Pasar a la redacción 2.1';tr = '2.1.sürüme geç';it = 'Vai all''edizione 2.1';de = 'Zur Version 2.1 wechseln'");
	WriteProcedureStartToLog(ProcedurePresentation);
	
	QueryText =
	"SELECT DISTINCT
	|	ReportsOptions.Ref,
	|	ReportsOptions.DeleteObjectKey AS ReportFullName
	|FROM
	|	Catalog.ReportsOptions AS ReportsOptions
	|WHERE
	|	ReportsOptions.DeleteObjectKey <> """"";
	
	Query = New Query;
	Query.Text = QueryText;
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		
		// Generate report information.
		ReportInformation = GenerateReportInformationByFullName(Selection.ReportFullName);
		
		// Validate the result
		If TypeOf(ReportInformation.ErrorText) = Type("String") Then
			WriteToLog(EventLogLevel.Error, ReportInformation.ErrorText, Selection.Ref);
			Continue;
		EndIf;
		
		OptionObject = Selection.Ref.GetObject();
		
		If OptionObject.ReportType = Enums.ReportTypes.DeleteUserReport
			Or OptionObject.ReportType = Enums.ReportTypes.External Then
			OptionObject.Custom = True;
		Else
			OptionObject.Custom = False;
		EndIf;
		
		OptionObject.Report = ReportInformation.Report;
		OptionObject.ReportType = ReportInformation.ReportType;
		
		If ReportInformation.ReportType = Enums.ReportTypes.External Then
			// Configuring external report option settings specific for all external report options.
			// All external report options are user options because predefined external report options are not 
			// registered in the application but are dynamically read each time.
			// 
			OptionObject.Custom = True;
			
			// External report options cannot be opened from the report panel.
			OptionObject.Placement.Clear();
			
		Else
			
			// Changing full subsystem names to references of the "Metadata object IDs" catalog.
			Edition21ArrangeSettingsBySections(OptionObject);
			
			// Transferring user settings from the tabular section to the information register.
			Edition21MoveUserSettingsToRegister(OptionObject);
			
		EndIf;
		
		// Options are supplied without an author.
		If Not OptionObject.Custom Then
			OptionObject.Author = Undefined;
		EndIf;
		
		OptionObject.DeleteObjectKey = "";
		OptionObject.DeleteObjectPresentation = "";
		OptionObject.DeleteQuickAccessExceptions.Clear();
		WritePredefinedObject(OptionObject);
	EndDo;
	
	WriteProcedureCompletionToLog(ProcedurePresentation);
EndProcedure

// [2.1.3.6] Fills in references of the predefined items of the "Report options" catalog.
Procedure FillPredefinedOptionsRefs() Export
	ProcedurePresentation = NStr("ru = 'Заполнить ссылки предопределенных вариантов отчетов'; en = 'Fill in links of predefined report options'; pl = 'Wypełnij linki predefiniowanych wariantów raportów';es_ES = 'Rellenar los enlaces de las variantes predeterminadas de los informes';es_CO = 'Rellenar los enlaces de las variantes predeterminadas de los informes';tr = 'Önceden tanımlanan rapor seçeneklerin referanslarını doldur';it = 'Compilare i link delle varianti di report predefinite';de = 'Füllen Sie Links zu vordefinierten Berichtsoptionen aus'");
	WriteProcedureStartToLog(ProcedurePresentation);
	
	// Generate a table of replacements of old option keys for relevant ones.
	Changes = KeysChanges();
	
	// Get report option references for key replacement. Exclude report options if their relevant keys 
	// are already registered or their old keys are not occupied.
	// 
	// 
	QueryText =
	"SELECT
	|	Changes.Report AS Report,
	|	Changes.OldOptionName AS OldOptionName,
	|	Changes.RelevantOptionName AS RelevantOptionName
	|INTO ttChanges
	|FROM
	|	&Changes AS Changes
	|
	|INDEX BY
	|	OldOptionName,
	|	RelevantOptionName
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	ReportsOptions.Ref AS ReportOption,
	|	CAST(ReportsOptions.Report AS Catalog.MetadataObjectIDs) AS ReportForKeysReplacement,
	|	ISNULL(ttChanges.RelevantOptionName, ReportsOptions.VariantKey) AS LatestOptionKey
	|INTO ttRelevant
	|FROM
	|	Catalog.ReportsOptions AS ReportsOptions
	|		LEFT JOIN ttChanges AS ttChanges
	|		ON ReportsOptions.Report = ttChanges.Report
	|			AND ReportsOptions.VariantKey = ttChanges.OldOptionName
	|WHERE
	|	ReportsOptions.Custom = FALSE
	|	AND ReportsOptions.ReportType = &ReportType
	|	AND ReportsOptions.DeletionMark = FALSE
	|	AND ReportsOptions.PredefinedVariant = &EmptyPredefined
	|
	|INDEX BY
	|	LatestOptionKey,
	|	ReportOption
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ttRelevant.ReportOption,
	|	PredefinedReportsOptions.Description,
	|	PredefinedReportsOptions.VariantKey,
	|	ISNULL(PredefinedReportsOptions.Ref, UNDEFINED) AS PredefinedVariant
	|FROM
	|	ttRelevant AS ttRelevant
	|		LEFT JOIN Catalog.PredefinedReportsOptions AS PredefinedReportsOptions
	|		ON ttRelevant.ReportForKeysReplacement = PredefinedReportsOptions.Report
	|			AND ttRelevant.LatestOptionKey = PredefinedReportsOptions.VariantKey";
	
	Query = New Query;
	Query.SetParameter("Changes", Changes);
	Query.SetParameter("ReportType", Enums.ReportTypes.Internal); // Extension support is not required.
	Query.SetParameter("EmptyPredefined", Catalogs.PredefinedReportsOptions.EmptyRef());
	Query.Text = QueryText;
	
	// Replace option names with references.
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		OptionObject = Selection.Ref.GetObject();
		OptionObject.AdditionalProperties.Insert("PredefinedObjectsFilling", True);
		OptionObject.AdditionalProperties.Insert("IndexSchema", False);
		If ValueIsFilled(Selection.PredefinedVariant) Then
			FillPropertyValues(OptionObject, Selection, "Description, VariantKey, PredefinedVariant");
			FoundItems = OptionObject.Placement.FindRows(New Structure("DeletePredefined", True));
			For Each TableRow In FoundItems Do
				OptionObject.Placement.Delete(TableRow);
			EndDo;
			OptionObject.Details = "";
			InfobaseUpdate.WriteObject(OptionObject);
		Else
			OptionObject.SetDeletionMark(True);
		EndIf;
	EndDo;
	
	WriteProcedureCompletionToLog(ProcedurePresentation);
	
EndProcedure

// [2.2.3.30] Reduces the number of quick settings in user report options to 2 pcs.
Procedure NarrowDownQuickSettings(IncomingParameters = Undefined) Export
	ProcedurePresentation = NStr("ru = 'Сокращение количества быстрых настроек в отчетах'; en = 'Reducing the number of quick settings in reports'; pl = 'Zmniejszenie ilości szybkich ustawień w raportach';es_ES = 'Disminución de la cantidad de los ajustes rápidos en los informes';es_CO = 'Disminución de la cantidad de los ajustes rápidos en los informes';tr = 'Raporlarda hızlı ayar sayısını azalt';it = 'Riduzione del numero di impostazioni rapide nei report';de = 'Reduzierung der Anzahl der Schnelleinstellungen in Berichten'");
	WriteProcedureStartToLog(ProcedurePresentation);
	
	// Reading information from a previous run with errors.
	Parameters = Common.CommonSettingsStorageLoad(
		ReportsOptionsClientServer.FullSubsystemName(),
		"NarrowDownQuickSettings");
	Query = New Query;
	If Parameters = Undefined Then
		Query.Text = "SELECT Ref, Report FROM Catalog.ReportsOptions WHERE Custom AND ReportType <> &External";
		Query.SetParameter("External", Enums.ReportTypes.External);
		AttemptNumber = 1;
	Else
		Query.Text = "SELECT Ref, Report FROM Catalog.ReportsOptions WHERE Ref IN (&OptionsWithErrors)";
		Query.SetParameter("OptionsWithErrors", Parameters.OptionsWithErrors);
		AttemptNumber = Parameters.AttemptNumber + 1;
	EndIf;
	ValueTable = Query.Execute().Unload();
	
	Written = 0;
	Errors = 0;
	ReportsCache = New Map;
	CheckBoxCache = Undefined;
	OptionsWithErrors = New Array;
	
	For Each TableRow In ValueTable Do
		ReportObject = ReportsCache.Get(TableRow.Report); // Read cache.
		If ReportObject = Undefined Then // Write to cache.
			Attachment = AttachReportObject(TableRow.Report, True);
			If Attachment.Success Then
				ReportObject = Attachment.Object;
				ReportMetadata = Attachment.Metadata;
				If Not ReportAttachedToMainForm(ReportMetadata, CheckBoxCache) Then
					// Report is not attached to the common report form.
					// The number of quick settings must be reduced by an applied code.
					ReportObject = "";
				EndIf;
			Else // The report is not found.
				WriteToLog(EventLogLevel.Error, Attachment.ErrorText, TableRow.Ref);
				ReportObject = "";
			EndIf;
			ReportsCache.Insert(TableRow.Report, ReportObject);
		EndIf;
		If ReportObject = "" Then
			Continue;
		EndIf;
		
		OptionObject = TableRow.Ref.GetObject();
		
		ErrorInformation = Undefined;
		Try
			WritingRequired = ReduceQuickSettingsNumber(OptionObject, ReportObject);
		Except
			ErrorInformation = ErrorInfo();
			WritingRequired = False;
		EndTry;
		If ErrorInformation <> Undefined Then // An error occurred.
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Вариант ""%1"" отчета ""%2"":'; en = 'Option ""%1"" of report ""%2"":'; pl = 'Wariant ""%1"" raportu ""%2"":';es_ES = 'Variante ""%1"" del informe ""%2"":';es_CO = 'Variante ""%1"" del informe ""%2"":';tr = '""%2"" raporunun ""%1"" seçeneği:';it = 'Opzione ""%1"" del report ""%2"":';de = 'Option ""%1"" des Berichts ""%2"":'")
				+ Chars.LF + NStr("ru = 'При уменьшении количества быстрых настроек пользовательского возникла ошибка:'; en = 'An error occurred when reducing the number of quick user settings:'; pl = 'Przy zmniejszeniu ilości szybkich ustawień użytkownika wystąpił błąd:';es_ES = 'Al disminuir la cantidad de los ajustes rápidos de usuarios ha ocurrido un error:';es_CO = 'Al disminuir la cantidad de los ajustes rápidos de usuarios ha ocurrido un error:';tr = 'Hızlı kullanıcı ayarlarının sayısı azaltılırken bir hata oluştu:';it = 'Si è verificato un errore durante la riduzione del numero di impostazioni rapide utente:';de = 'Bei der Reduzierung der Anzahl schneller benutzerdefinierter Einstellungen ist ein Fehler aufgetreten:'")
				+ Chars.LF + DetailErrorDescription(ErrorInformation),
				OptionObject.Ref, OptionObject.VariantKey, OptionObject.Report);
			WriteToLog(EventLogLevel.Error, ErrorText);
			OptionsWithErrors.Add(OptionObject.Ref);
			Errors = Errors + 1;
		EndIf;
		
		If WritingRequired Then
			OptionObject.AdditionalProperties.Insert("IndexSchema", False);
			OptionObject.AdditionalProperties.Insert("ReportObject", ReportObject);
			WritePredefinedObject(OptionObject);
			Written = Written + 1;
		EndIf;
	EndDo;
	
	If Errors > 0 Then
		// Writing information for the next run.
		Parameters = New Structure;
		Parameters.Insert("AttemptNumber", AttemptNumber);
		Parameters.Insert("OptionsWithErrors", OptionsWithErrors);
		
		Common.CommonSettingsStorageSave(
			ReportsOptionsClientServer.FullSubsystemName(),
			"NarrowDownQuickSettings",
			Parameters);
	ElsIf AttemptNumber > 1 Then
		// Deleting information from previous runs.
		Common.CommonSettingsStorageDelete(
			ReportsOptionsClientServer.FullSubsystemName(),
			"NarrowDownQuickSettings",
			UserName());
	EndIf;
	
	WriteProcedureCompletionToLog(ProcedurePresentation, Written);
	
	If Errors > 0 Then
		ErrorText = ProcedurePresentation + ":" + Chars.LF + StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Не удалось уменьшить количество быстрых настроек %1 отчетов.'; en = 'Cannot reduce a number of report quick settings %1.'; pl = 'Nie udało się zmniejszyć ilość szybkich ustawień %1 sprawozdań.';es_ES = 'No se ha podido disminuir la cantidad de los ajustes rápidos %1 de informes.';es_CO = 'No se ha podido disminuir la cantidad de los ajustes rápidos %1 de informes.';tr = 'Raporların hızlı ayarlarının sayısı azaltılamadı %1';it = 'Impossibile ridurre il numero di impostazioni rapide di report %1.';de = 'Die Anzahl der Schnelleinstellungen %1 für Berichte konnte nicht reduziert werden.'"), Errors);
		WriteLogEvent(ReportsOptionsClientServer.SubsystemDescription(Undefined),
			EventLogLevel.Warning, , , ErrorText);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Updating an infobase / Initial filling and update of catalogs.

// Updates cache of configuration metadata/applied extensions.
Function CommonDataNonexclusiveUpdate(Mode, SeparatedHandlers)
	
	////////////////////////////////////////////////////////////////////////////////
	// Only for predefined report options.
	// Update plan:
	
	Cache = New Structure;
	Cache.Insert("Mode",                  Mode);
	Cache.Insert("UpdateConfiguration",  Mode = "ConfigurationCommonData");
	Cache.Insert("UpdateExtensions",    Mode = "ExtensionsCommonData");
	Cache.Insert("SeparatedHandlers", SeparatedHandlers);
	Cache.Insert("HasChanges",       False);
	Cache.Insert("HasImportantChanges", False);
	Cache.Insert("OptionsTree", PredefinedItemsTree(?(Cache.UpdateConfiguration, "Internal", "Extension")));
	Cache.Insert("UpdateMeasurements", Cache.UpdateConfiguration AND Common.SubsystemExists("StandardSubsystems.PerformanceMonitor"));
	Cache.Insert("MeasurementsTable",  MeasurementsTable());
	Cache.Insert("SaaSModel",   Common.DataSeparationEnabled());
	Cache.Insert("Clarification", ?(Cache.Mode = "ConfigurationCommonData", NStr("ru = 'метаданные конфигурации'; en = 'configuration metadata'; pl = 'metadane konfiguracji';es_ES = 'metadatos de configuración';es_CO = 'metadatos de configuración';tr = 'yapılandırmanın meta verileri';it = 'metadati della configurazione';de = 'Konfigurations-Metadaten'"), NStr("ru = 'метаданные расширений'; en = 'extension metadata'; pl = 'metadane rozszerzeń';es_ES = 'metadatos de extensiones';es_CO = 'metadatos de extensiones';tr = 'uzantı meta verisi';it = 'metadati delle estensioni';de = 'Erweiterungs-Metadaten'")));
	
	// Update plan:
	
	////////////////////////////////////////////////////////////////////////////////
	// 1. Replace obsolete report option keys with relevant ones.
	UpdateKeysOfPredefinedItems(Cache);
	
	////////////////////////////////////////////////////////////////////////////////
	// 2. Update predefined report options and rewrite the constant where functional option bindings are 
	//    stored.
	UpdateSettingsOfPredefinedItems(Cache);
	
	////////////////////////////////////////////////////////////////////////////////
	// 3. Set a deletion mark for options of deleted reports.
	MarkOptionsOfDeletedReportsForDeletion(Cache);
	
	////////////////////////////////////////////////////////////////////////////////
	// 4. Write parameters to the register.
	WriteReportOptionsParameters(Cache);
	
	////////////////////////////////////////////////////////////////////////////////
	// 5. Write a slice of extension report option keys to the register.
	RecordCurrentExtensionsVersion(Cache);
	
	////////////////////////////////////////////////////////////////////////////////
	// 6. Update separated data in SaaS mode.
	If Cache.SaaSModel AND Cache.HasImportantChanges Then
		Handlers = Cache.SeparatedHandlers;
		If Handlers = Undefined Then
			Handlers = InfobaseUpdate.NewUpdateHandlerTable();
			Cache.SeparatedHandlers = Handlers;
		EndIf;
		
		Handler = Handlers.Add();
		Handler.ExecutionMode = "Seamless";
		Handler.Version    = "*";
		Handler.Procedure = "ReportsOptions.ConfigurationSharedDataNonexclusiveUpdate";
		Handler.Priority = 70;
	EndIf;
	
	ReportsServer.ClearValueTree(Cache.OptionsTree);
	
	Return Cache;
EndFunction

// Updates data of the ReportsOptions catalog.
Function SeparatedDataNonexclusiveUpdate(Mode)
	
	Cache = New Structure;
	Cache.Insert("Mode",               Mode);
	Cache.Insert("HasChanges",       False);
	Cache.Insert("HasImportantChanges", False);
	Cache.Insert("Clarification", Lower(ReportsClientServer.NameToPresentation(Mode)));
	
	////////////////////////////////////////////////////////////////////////////////
	// Update plan:
	
	////////////////////////////////////////////////////////////////////////////////
	// 1. Update separated report options.
	UpdateAreaContent(Cache);
	
	////////////////////////////////////////////////////////////////////////////////
	// 2. Set a deletion mark for options of deleted reports.
	MarkOptionsOfDeletedReportsForDeletion(Cache);
	
	Return Cache;
	
EndFunction

// Updating the search index of predefined report options.
Function DeferredDataUpdate(Mode, Full)
	If Mode = "ConfigurationCommonData" AND Not SharedDataIndexingAllowed() Then
		Return Undefined;
	EndIf;
	
	Cache = New Structure;
	Cache.Insert("Mode",               Mode);
	Cache.Insert("HasChanges",       False);
	Cache.Insert("HasImportantChanges", False);
	Cache.Insert("SharedData", Mode = "ConfigurationCommonData" Or Mode = "ExtensionsCommonData");
	Cache.Insert("Full",    Full);
	Cache.Insert("Clarification", Lower(ReportsClientServer.NameToPresentation(Mode)));
	Cache.Clarification = Cache.Clarification + ", " + ?(Full, NStr("ru = 'полное'; en = 'full'; pl = 'pełne';es_ES = 'completo';es_CO = 'completo';tr = 'tam';it = 'completo';de = 'vollständig'"), NStr("ru = 'по изменениям'; en = 'by changes'; pl = 'według zmian';es_ES = 'por cambios';es_CO = 'por cambios';tr = 'değişikliklere göre';it = 'secondo cambiamenti';de = 'durch Änderung'"));
	
	// Update plan:
	
	////////////////////////////////////////////////////////////////////////////////
	// 1. Update the report search index.
	UpdateSearchIndex(Cache);
	
	Return Cache;
EndFunction

// Updating the report search index.
Procedure UpdateSearchIndex(Cache)
	If Cache.Mode = "ConfigurationCommonData" AND Not SharedDataIndexingAllowed() Then
		Return;
	EndIf;
	
	ProcedurePresentation = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Обновление индекса поиска (%1)'; en = 'Updating search index (%1)'; pl = 'Aktualizacja indeksu wyszukiwania (%1)';es_ES = 'Actualización del índice de la búsqueda (%1)';es_CO = 'Actualización del índice de la búsqueda (%1)';tr = 'Arama endeksinin yenilenmesi (%1)';it = 'Aggiornamento dell''indice di ricerca (%1)';de = 'Aktualisierung des Suchindex (%1)'"), Cache.Clarification);
	WriteProcedureStartToLog(ProcedurePresentation);
	
	Query = New Query;
	
	If Cache.SharedData Then
		Search = New Structure("Report, VariantKey, IsOption", , , True);
		If Cache.Mode = "ConfigurationCommonData" Then
			OptionsTree = PredefinedItemsTree("Internal");
			Query.Text =
			"SELECT
			|	PredefinedReportsOptions.Ref,
			|	PredefinedReportsOptions.Report
			|FROM
			|	Catalog.PredefinedReportsOptions AS PredefinedReportsOptions
			|WHERE
			|	PredefinedReportsOptions.DeletionMark = FALSE";
		ElsIf Cache.Mode = "ExtensionsCommonData" Then
			OptionsTree = PredefinedItemsTree("Extension");
			Query.Text =
			"SELECT
			|	PredefinedExtensionsVersionsReportsOptions.Variant AS Ref,
			|	PredefinedExtensionsVersionsReportsOptions.Report
			|FROM
			|	InformationRegister.PredefinedExtensionsVersionsReportsOptions AS PredefinedExtensionsVersionsReportsOptions
			|WHERE
			|	PredefinedExtensionsVersionsReportsOptions.ExtensionsVersion = &ExtensionsVersion
			|	AND PredefinedExtensionsVersionsReportsOptions.Variant <> &EmptyRef";
			Query.SetParameter("ExtensionsVersion", SessionParameters.ExtensionsVersion);
			Query.SetParameter("EmptyRef", Catalogs.PredefinedExtensionsReportsOptions.EmptyRef());
		EndIf;
	Else
		Query.Text =
		"SELECT
		|	ReportsOptions.Ref,
		|	ReportsOptions.Report
		|FROM
		|	Catalog.ReportsOptions AS ReportsOptions
		|WHERE
		|	ReportsOptions.Custom
		|	AND ReportsOptions.ReportType = &ReportType
		|	AND ReportsOptions.Report IN(&AvailableReports)";
		Query.SetParameter("AvailableReports", New Array(ReportsOptionsCached.AvailableReports(False)));
		If Cache.Mode = "SeparatedConfigurationData" Then
			Query.SetParameter("ReportType", Enums.ReportTypes.Internal);
		ElsIf Cache.Mode = "SeparatedExtensionData" Then
			Query.SetParameter("ReportType", Enums.ReportTypes.Extension);
		EndIf;
	EndIf;
	
	ReportsCache = New Map;
	PreviousInfo = New Structure("SettingsHash, FieldDescriptions, FilterParameterDescriptions, Keywords");
	
	ErrorsList = New Array;
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		
		ReportObject = ReportsCache.Get(Selection.Report); // Read cache.
		If ReportObject = "" Then
			Continue; // Report is not attached. Error was registered earlier.
		EndIf;
		
		OptionObject = Selection.Ref.GetObject();
		
		If Cache.SharedData Then
			FillPropertyValues(Search, OptionObject, "Report, VariantKey");
			FoundItems = OptionsTree.Rows.FindRows(Search, True);
			If FoundItems.Count() = 0 Then
				ErrorText = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Вариант ""%1"" не найден для отчета ""%2""'; en = 'Option ""%1"" was not found for report ""%2""'; pl = 'Dla sprawozdania ""%2"" nie znaleziono wariantu ""%1""';es_ES = 'Opción ""%1"" no se ha encontrado para el informe ""%2""';es_CO = 'Opción ""%1"" no se ha encontrado para el informe ""%2""';tr = '""%2"" raporu için ""%1"" seçeneği bulunamadı';it = 'La variante ""%1"" non è stata trovata per il report ""%2""';de = 'Option ""%1"" wurde für Bericht ""%2"" nicht gefunden'"), 
					OptionObject.VariantKey, OptionObject.Report);
				WriteToLog(EventLogLevel.Error, ErrorText, OptionObject.Ref);
				Continue; // An error occurred.
			EndIf;
			
			OptionDetails = FoundItems[0];
			RowReport = OptionDetails.Parent;
			FillOptionRowDetails(OptionDetails, RowReport);
			
			// If an option is disabled, it cannot be searched for.
			If Not OptionDetails.Enabled Then
				Continue; // Filling is not required.
			EndIf;
			
			DCSettings = CommonClientServer.StructureProperty(OptionDetails.SystemInfo, "DCSettings");
			OptionObject.AdditionalProperties.Insert("DCSettings", DCSettings);
			OptionObject.AdditionalProperties.Insert("SearchSettings", OptionDetails.SearchSettings);
		EndIf;
		
		OptionObject.AdditionalProperties.Insert("ReportObject", ReportObject);
		
		FillPropertyValues(PreviousInfo, OptionObject);
		OptionObject.FieldDescriptions = "";
		OptionObject.FilterParameterDescriptions = "";
		OptionObject.Keywords = "";
		If Cache.Full Then // Reindexe forcedly, without checking the hash.
			OptionObject.AdditionalProperties.Insert("IndexSchema", True);
		EndIf;
		
		Try
			SchemaIndexed = IndexSchemaContent(OptionObject);
		Except
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Не удалось перестроить индекс поиска для варианта ""%1"" отчета ""%2"". Возможно, отчет неисправен.'; en = 'Cannot rebuild the search index for option ""%1"" of report ""%2"". The report may be invalid.'; pl = 'Nie udało się przebudować indeks wyszukiwania dla wariantu ""%1"" raportu ""%2"". Możliwe, że raport jest uszkodzony.';es_ES = 'No se ha podido reconstruir el índice de la búsqueda para la variante ""%1"" del informe ""%2"". Es posible que el informe esté dañado.';es_CO = 'No se ha podido reconstruir el índice de la búsqueda para la variante ""%1"" del informe ""%2"". Es posible que el informe esté dañado.';tr = '""%1"" raporun ""%2"" seçeneği için arama endeksi yeniden yapılandırılamadı. Rapor arızalı olabilir.';it = 'Impossibile ricostruire l''indice di ricerca per la variante ""%1"" del report ""%2"". Il report potrebbe non essere valido.';de = 'Es war nicht möglich, den Suchindex für die Option ""%1"" des Berichts ""%2"" umzustellen. Möglicherweise ist der Bericht fehlerhaft.'"), 
				OptionObject.VariantKey, OptionObject.Report);
			WriteToLog(EventLogLevel.Error, ErrorText + Chars.LF + DetailErrorDescription(ErrorInfo()), OptionObject.Ref);
			ErrorsList.Add(ErrorText);
			Continue;
		EndTry;
		
		If SchemaIndexed AND SearchSettingsChanged(OptionObject, PreviousInfo) Then
			If Cache.SharedData Then
				WritePredefinedObject(OptionObject);
			Else
				InfobaseUpdate.WriteObject(OptionObject);
			EndIf;
			Cache.HasChanges = True;
		EndIf;
		
		// Saving an initialized object to cache.
		If ReportObject = Undefined Then
			ReportObject = OptionObject.AdditionalProperties.ReportObject;
			If ReportObject = Undefined Then
				ReportObject = ""; // A report was not attached, registering a blank string to skip other options.
			EndIf;
			ReportsCache.Insert(Selection.Report, ReportObject);
		EndIf;
	EndDo;
	
	If Cache.SharedData Then
		ReportsServer.ClearValueTree(OptionsTree);
	EndIf;
	
	WriteProcedureCompletionToLog(ProcedurePresentation);
	
EndProcedure

// Replacing obsolete report option keys with relevant ones.
Procedure UpdateKeysOfPredefinedItems(Cache)
	ProcedurePresentation = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Обновление ключей вариантов отчетов (%1)'; en = 'Updating report option keys (%1)'; pl = 'Aktualizacja kluczy wariantów sprawozdań (%1)';es_ES = 'Actualización de las claves de variantes de los informes (%1)';es_CO = 'Actualización de las claves de variantes de los informes (%1)';tr = 'Rapor seçeneklerinin anahtarlarının güncellenmesi (%1)';it = 'Aggiornamento delle chiavi delle varianti dei report(%1)';de = 'Berichtsoptionsschlüssel aktualisieren (%1)'"), Cache.Clarification);
	WriteProcedureStartToLog(ProcedurePresentation);
	
	// Generate a table of replacements of old option keys for relevant ones.
	Changes = KeysChanges();
	
	// Get report option references for key replacement. Exclude report options if their relevant keys 
	//   are already registered or their old keys are not occupied.
	//   
	//   
	QueryText =
	"SELECT
	|	Changes.Report,
	|	Changes.OldOptionName,
	|	Changes.RelevantOptionName
	|INTO ttChanges
	|FROM
	|	&Changes AS Changes
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	ttChanges.Report,
	|	ttChanges.RelevantOptionName,
	|	ReportOptionsOld.Ref
	|FROM
	|	ttChanges AS ttChanges
	|		LEFT JOIN Catalog.PredefinedReportsOptions AS ReportOptionsLatest
	|		ON ttChanges.Report = ReportOptionsLatest.Report
	|			AND ttChanges.RelevantOptionName = ReportOptionsLatest.VariantKey
	|		LEFT JOIN Catalog.PredefinedReportsOptions AS ReportOptionsOld
	|		ON ttChanges.Report = ReportOptionsOld.Report
	|			AND ttChanges.OldOptionName = ReportOptionsOld.VariantKey
	|WHERE
	|	ReportOptionsLatest.Ref IS NULL 
	|	AND NOT ReportOptionsOld.Ref IS NULL ";
	
	If Cache.Mode = "ExtensionsCommonData" Then
		QueryText = StrReplace(QueryText, ".PredefinedReportsOptions", ".PredefinedExtensionsReportsOptions");
	EndIf;
	
	Query = New Query;
	Query.SetParameter("Changes", Changes);
	Query.Text = QueryText;
	
	// Replace obsolete option names with relevant ones.
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		Cache.HasChanges = True;
		Cache.HasImportantChanges = True;
		OptionObject = Selection.Ref.GetObject();
		OptionObject.VariantKey = Selection.RelevantOptionName;
		WritePredefinedObject(OptionObject);
	EndDo;
	
	WriteProcedureCompletionToLog(ProcedurePresentation);
EndProcedure

// Actualizing predefined report options.
Procedure UpdateSettingsOfPredefinedItems(Cache)
	ProcedurePresentation = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Обновление настроек предопределенных (%1)'; en = 'Update of predefined settings (%1)'; pl = 'Aktualizacja ustawień predefiniowanych (%1)';es_ES = 'Actualización de los ajustes predeterminados (%1)';es_CO = 'Actualización de los ajustes predeterminados (%1)';tr = 'Önceden tanımlanan ayarlarının güncellenmesi (%1)';it = 'Aggiornamento delle impostazioni predefinite (%1)';de = 'Vordefinierte Einstellungen aktualisieren (%1)'"), Cache.Clarification);
	WriteProcedureStartToLog(ProcedurePresentation);
	
	OptionsAttributes = Metadata.Catalogs.ReportsOptions.Attributes;
	
	FunctionalOptionsTable = New ValueTable;
	FunctionalOptionsTable.Columns.Add("Report",                   OptionsAttributes.Report.Type);
	FunctionalOptionsTable.Columns.Add("PredefinedVariant", OptionsAttributes.PredefinedVariant.Type);
	FunctionalOptionsTable.Columns.Add("FunctionalOptionName",  New TypeDescription("String"));
	
	Cache.Insert("FunctionalOptionsTable", FunctionalOptionsTable);
	
	ReportsWithSettingsList = New ValueList;
	Cache.Insert("ReportsWithSettingsList", ReportsWithSettingsList);
	
	Cache.OptionsTree.Columns.Add("FoundInDatabase", New TypeDescription("Boolean"));
	Cache.OptionsTree.Columns.Add("OptionFromBase", New TypeDescription("ValueTableRow"));
	
	If Cache.Mode = "ConfigurationCommonData" Then
		Cache.OptionsTree.Columns.Add("ParentOption", New TypeDescription("CatalogRef.PredefinedReportsOptions"));
		QueryText = "SELECT * FROM Catalog.PredefinedReportsOptions ORDER BY DeletionMark";
		BlankRef = Catalogs.PredefinedReportsOptions.EmptyRef();
	ElsIf Cache.Mode = "ExtensionsCommonData" Then
		Cache.OptionsTree.Columns.Add("ParentOption", New TypeDescription("CatalogRef.PredefinedExtensionsReportsOptions"));
		QueryText = "SELECT * FROM Catalog.PredefinedExtensionsReportsOptions ORDER BY DeletionMark";
		BlankRef = Catalogs.PredefinedExtensionsReportsOptions.EmptyRef();
	EndIf;
	
	// Mapping information from database and metadata and marking obsolete object from the base for deletion.
	SearchForOption = New Structure("Report, VariantKey, FoundInDatabase, IsOption");
	SearchForOption.FoundInDatabase = False;
	SearchForOption.IsOption        = True;
	Query = New Query(QueryText);
	PredefinedItemsTable = Query.Execute().Unload();
	For Each OptionFromBase In PredefinedItemsTable Do
		FillPropertyValues(SearchForOption, OptionFromBase, "Report, VariantKey");
		FoundItems = Cache.OptionsTree.Rows.FindRows(SearchForOption, True);
		If FoundItems.Count() = 0 Then
			If OptionFromBase.DeletionMark AND OptionFromBase.Parent = BlankRef Then
				Continue; // No action required.
			EndIf;
			OptionObject = OptionFromBase.Ref.GetObject();
			OptionObject.DeletionMark = True;
			OptionObject.Parent = BlankRef;
			WritePredefinedObject(OptionObject);
			Cache.HasChanges = True;
			Cache.HasImportantChanges = True;
		Else
			OptionDetails = FoundItems[0];
			FillOptionRowDetails(OptionDetails);
			OptionDetails.FoundInDatabase = True;
			OptionDetails.OptionFromBase = OptionFromBase;
		EndIf;
	EndDo;
	
	// Adding and updating information in the database.
	For Each ReportDetails In Cache.OptionsTree.Rows Do
		MainOptionRef = BlankRef;
		MainOption = ReportDetails.MainOption;
		If TypeOf(MainOption) = Type("ValueTreeRow") Then
			FillOptionRowDetails(MainOption);
			MainOption.ParentOption = BlankRef;
			MainOptionRef = UpdatePredefinedItem(Cache, MainOption); // Option without a parent.
		EndIf;
		If ReportDetails.DefineFormSettings Then
			ReportsWithSettingsList.Add(ReportDetails.Report);
		EndIf;
		For Each OptionDetails In ReportDetails.Rows Do
			FillOptionRowDetails(OptionDetails);
			If OptionDetails = MainOption Then
				OptionRef = MainOptionRef;
			Else
				OptionDetails.ParentOption = MainOptionRef;
				OptionRef = UpdatePredefinedItem(Cache, OptionDetails);
			EndIf;
			For Each FunctionalOptionName In OptionDetails.FunctionalOptions Do
				LinkWithFunctionalOption = FunctionalOptionsTable.Add();
				LinkWithFunctionalOption.Report                   = OptionDetails.Report;
				LinkWithFunctionalOption.PredefinedVariant = OptionRef;
				LinkWithFunctionalOption.FunctionalOptionName  = FunctionalOptionName;
			EndDo;
		EndDo;
	EndDo;
	
	WriteProcedureCompletionToLog(ProcedurePresentation);
EndProcedure

// Writes option settings to catalog data.
Function UpdatePredefinedItem(Cache, OptionDetails)
	OptionFromBase = OptionDetails.OptionFromBase;
	If Cache.UpdateMeasurements Then
		varKey = ?(OptionDetails.FoundInDatabase, OptionFromBase.MeasurementsKey, "");
		RegisterOptionMeasurementsForUpdate(Cache, varKey, OptionDetails.MeasurementsKey, OptionDetails.Description);
	EndIf;
	If OptionDetails.FoundInDatabase Then
		If KeySettingsOfPredefinedItemChanged(OptionDetails, OptionFromBase) Then
			Cache.HasImportantChanges = True; // Rewriting key settings (rewriting separated data is required).
		ElsIf SecondarySettingsOfPredefinedItemChanged(OptionDetails, OptionFromBase) Then
			// Rewriting without separated data update.
		Else
			Return OptionFromBase.Ref;
		EndIf;
		
		OptionObject = OptionDetails.OptionFromBase.Ref.GetObject();
		OptionObject.Placement.Clear();
		If OptionObject.DeletionMark Then
			OptionObject.DeletionMark = False;
		EndIf;
	Else
		Cache.HasImportantChanges = True; // Registering a new object (separated data update is required).
		If Cache.Mode = "ConfigurationCommonData" Then
			OptionObject = Catalogs.PredefinedReportsOptions.CreateItem();
		ElsIf Cache.Mode = "ExtensionsCommonData" Then
			OptionObject = Catalogs.PredefinedExtensionsReportsOptions.CreateItem();
		EndIf;
	EndIf;
	
	FillPropertyValues(OptionObject, OptionDetails, "Report, VariantKey, Description, Enabled, VisibleByDefault, Details, GroupByReport");
	
	OptionObject.Parent = OptionDetails.ParentOption;
	
	For Each KeyAndValue In OptionDetails.Placement Do
		SubsystemRef = Common.MetadataObjectID(KeyAndValue.Key);
		If TypeOf(SubsystemRef) = Type("String") Then
			Continue;
		EndIf;
		PlacementRow = OptionObject.Placement.Add();
		PlacementRow.Subsystem = SubsystemRef;
		PlacementRow.Important  = (Lower(KeyAndValue.Value) = Lower("Important"));
		PlacementRow.SeeAlso = (Lower(KeyAndValue.Value) = Lower("SeeAlso"));
	EndDo;
	
	If Cache.UpdateMeasurements Then
		OptionObject.MeasurementsKey = OptionDetails.MeasurementsKey;
	EndIf;
	
	Cache.HasChanges = True;
	WritePredefinedObject(OptionObject);
	
	Return OptionObject.Ref;
EndFunction

// Defines whether key settings of the predefined report option changed.
Function KeySettingsOfPredefinedItemChanged(OptionDetails, OptionFromBase)
	If OptionFromBase.DeletionMark = True // Description is received => remove the deletion mark.
		Or OptionFromBase.Description <> OptionDetails.Description
		Or OptionFromBase.Parent <> OptionDetails.ParentOption
		Or OptionFromBase.VisibleByDefault <> OptionDetails.VisibleByDefault Then
		Return True;
	Else
		Return False;
	EndIf;
EndFunction

// Determines whether the secondary settings of the predefined report option have changed.
Function SecondarySettingsOfPredefinedItemChanged(OptionDetails, OptionFromBase)
	// Header
	If OptionFromBase.Enabled <> OptionDetails.Enabled
		Or OptionFromBase.Details <> OptionDetails.Details
		Or OptionFromBase.MeasurementsKey <> OptionDetails.MeasurementsKey
		Or OptionFromBase.GroupByReport <> OptionDetails.GroupByReport Then
		Return True;
	EndIf;
	
	// Placement table
	PlacementTable = OptionFromBase.Placement;
	If PlacementTable.Count() <> OptionDetails.Placement.Count() Then
		Return True;
	EndIf;
	
	For Each KeyAndValue In OptionDetails.Placement Do
		Subsystem = Common.MetadataObjectID(KeyAndValue.Key);
		If TypeOf(Subsystem) = Type("String") Then
			Continue;
		EndIf;
		PlacementRow = PlacementTable.Find(Subsystem, "Subsystem");
		If PlacementRow = Undefined
			Or PlacementRow.Important <> (Lower(KeyAndValue.Value) = Lower("Important"))
			Or PlacementRow.SeeAlso <> (Lower(KeyAndValue.Value) = Lower("SeeAlso")) Then
			Return True;
		EndIf;
	EndDo;
	
	Return False;
EndFunction

// Defines whether settings of the predefined report option search changed.
Function SearchSettingsChanged(OptionFromBase, PreviousInfo)
	If OptionFromBase.SettingsHash <> PreviousInfo.SettingsHash
		Or OptionFromBase.FieldDescriptions <> PreviousInfo.FieldDescriptions
		Or OptionFromBase.FilterParameterDescriptions <> PreviousInfo.FilterParameterDescriptions
		Or OptionFromBase.Keywords <> PreviousInfo.Keywords Then
		Return True;
	Else
		Return False;
	EndIf;
EndFunction

// Adjusts separated data to shared data.
Procedure UpdateAreaContent(Cache)
	ProcedurePresentation = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Обновление вариантов отчетов (%1)'; en = 'Updating report options (%1)'; pl = 'Aktualizacja wariantów sprawozdań (%1)';es_ES = 'Actualuzación de las variantes de los informes (%1)';es_CO = 'Actualuzación de las variantes de los informes (%1)';tr = 'Rapor seçeneklerinin güncellenmesi (%1)';it = 'Aggiornamento delle varianti dei report (%1)';de = 'Aktualisierung der Berichtsoptionen (%1)'"), Cache.Clarification);
	WriteProcedureStartToLog(ProcedurePresentation);
	
	// Updating predefined option information.
	QueryText =
	"SELECT
	|	PredefinedConfigurations.Ref AS PredefinedVariant,
	|	PredefinedConfigurations.Description AS Description,
	|	PredefinedConfigurations.Report AS Report,
	|	PredefinedConfigurations.GroupByReport AS GroupByReport,
	|	PredefinedConfigurations.VariantKey AS VariantKey,
	|	PredefinedConfigurations.VisibleByDefault AS VisibleByDefault,
	|	PredefinedConfigurations.Parent AS Parent
	|INTO ttPredefined
	|FROM
	|	Catalog.PredefinedReportsOptions AS PredefinedConfigurations
	|WHERE
	|	PredefinedConfigurations.DeletionMark = FALSE
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ReportsOptions.Ref,
	|	ReportsOptions.DeletionMark,
	|	ReportsOptions.Report,
	|	ReportsOptions.ReportType,
	|	ReportsOptions.VariantKey,
	|	ReportsOptions.Description,
	|	ReportsOptions.PredefinedVariant,
	|	ReportsOptions.VisibleByDefault,
	|	ReportsOptions.Parent,
	|	ReportsOptions.DefaultVisibilityOverridden
	|INTO ttReportOptions
	|FROM
	|	Catalog.ReportsOptions AS ReportsOptions
	|WHERE
	|	(ReportsOptions.ReportType = &ReportType
	|		OR VALUETYPE(ReportsOptions.Report) = &AttributeTypeReport)
	|	AND ReportsOptions.Custom = FALSE
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CASE
	|		WHEN ttPredefined.PredefinedVariant IS NULL 
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS SetDeletionMark,
	|	CASE
	|		WHEN ttReportOptions.Ref IS NULL 
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS CreateNew,
	|	ttPredefined.PredefinedVariant AS PredefinedVariant,
	|	ttPredefined.Description AS Description,
	|	ttPredefined.Report AS Report,
	|	ttPredefined.VariantKey AS VariantKey,
	|	ttPredefined.GroupByReport AS GroupByReport,
	|	CASE
	|		WHEN ttPredefined.Parent = &EmptyOptionRef
	|			THEN UNDEFINED
	|		ELSE ttPredefined.Parent
	|	END AS PredefinedOptionParent,
	|	CASE
	|		WHEN ttReportOptions.DefaultVisibilityOverridden
	|			THEN ttReportOptions.VisibleByDefault
	|		ELSE ttReportOptions.VisibleByDefault
	|	END AS VisibleByDefault,
	|	ttReportOptions.Ref AS AttributeRef,
	|	ttReportOptions.Parent AS AttributeParent,
	|	ttReportOptions.Report AS AttributeReport,
	|	ttReportOptions.VariantKey AS AttributeVariantKey,
	|	ttReportOptions.Description AS AttributeDescription,
	|	ttReportOptions.PredefinedVariant AS AttributePredefinedVariant,
	|	ttReportOptions.DeletionMark AS AttributeDeletionMark,
	|	ttReportOptions.VisibleByDefault AS AttributeVisibleByDefault
	|FROM
	|	ttReportOptions AS ttReportOptions
	|		FULL JOIN ttPredefined AS ttPredefined
	|		ON ttReportOptions.PredefinedVariant = ttPredefined.PredefinedVariant";
	
	Query = New Query;
	If Cache.Mode = "SeparatedConfigurationData" Then
		Query.SetParameter("ReportType", Enums.ReportTypes.Internal);
		Query.SetParameter("AttributeTypeReport", Type("CatalogRef.MetadataObjectIDs"));
		Query.SetParameter("EmptyOptionRef", Catalogs.PredefinedReportsOptions.EmptyRef());
	ElsIf Cache.Mode = "SeparatedExtensionData" Then
		Query.SetParameter("ReportType", Enums.ReportTypes.Extension);
		Query.SetParameter("AttributeTypeReport", Type("CatalogRef.ExtensionObjectIDs"));
		Query.SetParameter("EmptyOptionRef", Catalogs.PredefinedExtensionsReportsOptions.EmptyRef());
		QueryText = StrReplace(QueryText, ".PredefinedReportsOptions", ".PredefinedExtensionsReportsOptions");
	EndIf;
	Query.Text = QueryText;
	
	Cache.Insert("EmptyRef", Catalogs.ReportsOptions.EmptyRef());
	Cache.Insert("SearchForParents", New Map);
	Cache.Insert("ProcessedPredefinedItems", New Array);
	Cache.Insert("MainOptions", New ValueTable);
	Cache.MainOptions.Columns.Add("Report", Metadata.Catalogs.ReportsOptions.Attributes.Report.Type);
	Cache.MainOptions.Columns.Add("Variant", New TypeDescription("CatalogRef.ReportsOptions"));
	
	Templates = New Structure;
	
	Templates.Insert("MarkForDeletion", New Structure);
	Templates.MarkForDeletion.Insert("Parent", Cache.EmptyRef);
	Templates.MarkForDeletion.Insert("DeletionMark", True);
	
	Templates.Insert("NewData", New Structure("DeletionMark, Parent,
		|Description, Report, VariantKey, PredefinedVariant, VisibleByDefault"));
	
	PredefinedItemsPivotTable = Query.Execute().Unload();
	PredefinedItemsPivotTable.Columns.Add("Processed", New TypeDescription("Boolean"));
	PredefinedItemsPivotTable.Columns.Add("Parent", New TypeDescription("CatalogRef.ReportsOptions"));
	
	// Updating main predefined options (without a parent).
	Search = New Structure("PredefinedOptionParent, SetDeletionMark", Undefined, False);
	FoundItems = PredefinedItemsPivotTable.FindRows(Search);
	For Each TableRow In FoundItems Do
		If TableRow.Processed Then
			Continue;
		EndIf;
		If Cache.ProcessedPredefinedItems.Find(TableRow.PredefinedVariant) <> Undefined Then
			TableRow.SetDeletionMark = True;
		EndIf;
		
		TableRow.Parent = Cache.EmptyRef;
		UpdateSeparatedPredefinedItem(Cache, Templates, TableRow);
		
		If Not TableRow.SetDeletionMark
			AND TableRow.GroupByReport
			AND Cache.SearchForParents.Get(TableRow.Report) = Undefined Then
			Cache.SearchForParents.Insert(TableRow.Report, TableRow.AttributeRef);
			MainOption = Cache.MainOptions.Add();
			MainOption.Report   = TableRow.Report;
			MainOption.Variant = TableRow.AttributeRef;
		EndIf;
	EndDo;
	
	// Updating all remaining predefined options (subordinates).
	PredefinedItemsPivotTable.Sort("SetDeletionMark Asc");
	For Each TableRow In PredefinedItemsPivotTable Do
		If TableRow.Processed Then
			Continue;
		EndIf;
		If Cache.ProcessedPredefinedItems.Find(TableRow.PredefinedVariant) <> Undefined Then
			TableRow.SetDeletionMark = True;
		EndIf;
		If TableRow.SetDeletionMark Then
			ParentRef = Cache.EmptyRef;
		Else
			ParentRef = Cache.SearchForParents.Get(TableRow.Report);
		EndIf;
		
		TableRow.Parent = ParentRef;
		UpdateSeparatedPredefinedItem(Cache, Templates, TableRow);
	EndDo;
	
	// Updating user option parents.
	QueryText = 
	"SELECT
	|	MainReportOptions.Report,
	|	MainReportOptions.Variant
	|INTO ttMain
	|FROM
	|	&MainReportOptions AS MainReportOptions
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ReportsOptions.Ref,
	|	ttMain.Variant AS Parent
	|FROM
	|	Catalog.ReportsOptions AS ReportsOptions
	|		INNER JOIN ttMain AS ttMain
	|		ON ReportsOptions.Report = ttMain.Report
	|			AND ReportsOptions.Parent <> ttMain.Variant
	|			AND ReportsOptions.Parent.Parent <> ttMain.Variant
	|			AND ReportsOptions.Ref <> ttMain.Variant
	|WHERE
	|	ReportsOptions.Custom 
	|	OR NOT ReportsOptions.DeletionMark";
	
	Query = New Query;
	Query.SetParameter("MainReportOptions", Cache.MainOptions);
	Query.Text = QueryText;
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		Cache.HasChanges = True;
		OptionObject = Selection.Ref.GetObject();
		OptionObject.Parent = Selection.Parent;
		OptionObject.Lock();
		InfobaseUpdate.WriteObject(OptionObject);
	EndDo;
	
	WriteProcedureCompletionToLog(ProcedurePresentation);
EndProcedure

// Updates predefined data in separated mode.
Procedure UpdateSeparatedPredefinedItem(Cache, Templates, TableRow)
	If TableRow.Processed Then
		Return;
	EndIf;
	
	TableRow.Processed = True;
	
	If TableRow.SetDeletionMark Then // Mark for deletion.
		If PropertiesValuesMatch(Templates.MarkForDeletion, TableRow, "Attribute") Then
			Return; // Already marked.
		EndIf;
		OptionObject = TableRow.AttributeRef.GetObject();
		FillPropertyValues(OptionObject, Templates.MarkForDeletion);
	Else
		If TableRow.GroupByReport AND Not ValueIsFilled(TableRow.PredefinedOptionParent) Then
			TableRow.Parent = Cache.EmptyRef;
		EndIf;
		Cache.ProcessedPredefinedItems.Add(TableRow.PredefinedVariant);
		FillPropertyValues(Templates.NewData, TableRow);
		Templates.NewData.DeletionMark = False;
		If TableRow.CreateNew Then // Add.
			OptionObject = Catalogs.ReportsOptions.CreateItem();
			OptionObject.PredefinedVariant = TableRow.PredefinedVariant;
			OptionObject.Custom = False;
		Else // Update (if there are changes).
			If PropertiesValuesMatch(Templates.NewData, TableRow, "Attribute") Then
				Return; // No changes.
			EndIf;
			// Transferring user settings.
			ReplaceUserSettingsKeys(Templates.NewData, TableRow);
			OptionObject = TableRow.AttributeRef.GetObject();
		EndIf;
		If OptionObject.DefaultVisibilityOverridden Then
			ExcludeProperties = "VisibleByDefault";
		Else
			ExcludeProperties = Undefined;
		EndIf;
		FillPropertyValues(OptionObject, Templates.NewData, , ExcludeProperties);
		ReportByStringType = ReportsOptionsClientServer.ReportByStringType(Undefined, OptionObject.Report);
		OptionObject.ReportType = Enums.ReportTypes[ReportByStringType];
	EndIf;
	
	Cache.HasChanges = True;
	OptionObject.Lock();
	InfobaseUpdate.WriteObject(OptionObject);
	
	TableRow.AttributeRef = OptionObject.Ref;
EndProcedure

// Returns True if values of the Structures and Collections properties match Prefix.
Function PropertiesValuesMatch(Structure, Collection, PrefixInCollection = "")
	For Each KeyAndValue In Structure Do
		If Collection[PrefixInCollection + KeyAndValue.Key] <> KeyAndValue.Value Then
			Return False;
		EndIf;
	EndDo;
	Return True;
EndFunction

// Setting a deletion mark for deleted report options.
Procedure MarkOptionsOfDeletedReportsForDeletion(Cache)
	ProcedurePresentation = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Удаление вариантов удаленных отчетов (%1)'; en = 'Deletion of deleted report options (%1)'; pl = 'Usunięcie wariantów usuniętych raportów (%1)';es_ES = 'Eliminación de las variantes de los informes eliminados (%1)';es_CO = 'Eliminación de las variantes de los informes eliminados (%1)';tr = 'Silinmiş raporların seçeneklerini sil (%1)';it = 'Eliminazione delle varianti di report (%1) cancellate';de = 'Löschen von entfernten Berichtsoptionen (%1)'"), Cache.Clarification);
	WriteProcedureStartToLog(ProcedurePresentation);
	
	Query = New Query;
	QueryText =
	"SELECT
	|	ReportsOptions.Ref AS Ref
	|FROM
	|	Catalog.ReportsOptions AS ReportsOptions
	|WHERE
	|	NOT ReportsOptions.DeletionMark
	|	AND ReportsOptions.ReportType = &ReportType
	|	AND ISNULL(ReportsOptions.Report.DeletionMark, TRUE)";
	
	If Cache.Mode = "ConfigurationCommonData" Then
		QueryText = StrReplace(QueryText, ".ReportsOptions", ".PredefinedReportsOptions");
		QueryText = StrReplace(QueryText, "AND ReportsOptions.ReportType = &ReportType", "");
	ElsIf Cache.Mode = "ExtensionsCommonData" Then
		QueryText = StrReplace(QueryText, ".ReportsOptions", ".PredefinedExtensionsReportsOptions");
		QueryText = StrReplace(QueryText, "AND ReportsOptions.ReportType = &ReportType", "");
	ElsIf Cache.Mode = "SeparatedConfigurationData" Then
		Query.SetParameter("ReportType", Enums.ReportTypes.Internal);
	ElsIf Cache.Mode = "SeparatedExtensionData" Then
		Query.SetParameter("ReportType", Enums.ReportTypes.Extension);
	EndIf;
	
	Query.Text = QueryText;
	OptionsReferencesArray = Query.Execute().Unload().UnloadColumn("Ref");
	For Each OptionRef In OptionsReferencesArray Do
		Cache.HasChanges = True;
		Cache.HasImportantChanges = True;
		OptionObject = OptionRef.GetObject();
		OptionObject.Lock();
		OptionObject.DeletionMark = True;
		WritePredefinedObject(OptionObject);
	EndDo;
	
	WriteProcedureCompletionToLog(ProcedurePresentation);
EndProcedure

// Transferring custom settings of the option from the relevant storage.
Procedure ReplaceUserSettingsKeys(OldOption, UpdatedOption)
	If OldOption.VariantKey = UpdatedOption.VariantKey
		Or Not ValueIsFilled(OldOption.VariantKey)
		Or Not ValueIsFilled(UpdatedOption.VariantKey)
		Or TypeOf(UpdatedOption.Report) <> Type("CatalogRef.MetadataObjectIDs") Then
		Return;
	EndIf;
	
	ReportFullName = UpdatedOption.Report.FullName;
	OldObjectKey = ReportFullName +"/"+ OldOption.VariantKey;
	NewObjectKey = ReportFullName +"/"+ UpdatedOption.VariantKey;
	
	Filter = New Structure("ObjectKey", OldObjectKey);
	StorageSelection = ReportsUserSettingsStorage.Select(Filter);
	SuccessiveReadingErrors = 0;
	While True Do
		// Reading settings from the storage by the old key.
		Try
			GotSelectionItem = StorageSelection.Next();
			SuccessiveReadingErrors = 0;
		Except
			GotSelectionItem = Undefined;
			SuccessiveReadingErrors = SuccessiveReadingErrors + 1;
			WriteToLog(EventLogLevel.Error,
				NStr("ru = 'В процессе выборки вариантов отчетов из стандартного хранилища возникла ошибка:'; en = 'An error occurred when selecting report options from the standard storage:'; pl = 'Wystąpił błąd podczas wybierania wariantów sprawozdania z pamięci:';es_ES = 'Ha ocurrido un error al seleccionar las opciones de informes desde el almacenamiento estándar:';es_CO = 'Ha ocurrido un error al seleccionar las opciones de informes desde el almacenamiento estándar:';tr = 'Standart depolama alanından rapor seçenekleri seçilirken bir hata oluştu:';it = 'Un errore si è registrato durante la selezione delle varianti report dall''archivio standard:';de = 'Beim Auswählen der Berichtsoptionen aus dem Standardspeicher ist ein Fehler aufgetreten:'")
					+ Chars.LF + DetailErrorDescription(ErrorInfo()),
				OldOption.Ref);
		EndTry;
		
		If GotSelectionItem = False Then
			Break;
		ElsIf GotSelectionItem = Undefined Then
			If SuccessiveReadingErrors > 100 Then
				Break;
			Else
				Continue;
			EndIf;
		EndIf;
		
		// Reading settings description.
		SettingsDetails = ReportsUserSettingsStorage.GetDescription(
			StorageSelection.ObjectKey,
			StorageSelection.SettingsKey,
			StorageSelection.User);
		
		// Writing settings to the storage by a new key.
		ReportsUserSettingsStorage.Save(
			NewObjectKey,
			StorageSelection.SettingsKey,
			StorageSelection.Settings,
			SettingsDetails,
			StorageSelection.User);
	EndDo;
	
	// Clearing old storage settings.
	ReportsUserSettingsStorage.Delete(OldObjectKey, Undefined, Undefined);
EndProcedure

// Writes a predefined object.
Procedure WritePredefinedObject(OptionObject)
	OptionObject.AdditionalProperties.Insert("PredefinedObjectsFilling");
	InfobaseUpdate.WriteObject(OptionObject);
EndProcedure

// Registers changes in the measurement table.
Procedure RegisterOptionMeasurementsForUpdate(Cache, Val OldKey, Val UpdatedKey, Val UpdatedDescription)
	If IsBlankString(OldKey) Then
		OldKey = UpdatedKey;
	EndIf;
	
	MeasurementUpdating = Cache.MeasurementsTable.Add();
	MeasurementUpdating.OldName     = OldKey     + ".Opening";
	MeasurementUpdating.UpdatedName = UpdatedKey + ".Opening";
	MeasurementUpdating.UpdatedDescription = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Отчет ""%1"" (открытие)'; en = 'Report ""%1"" (opening)'; pl = 'Raport ""%1"" (otwarcie)';es_ES = 'Informe ""%1"" (apertura)';es_CO = 'Informe ""%1"" (apertura)';tr = 'Rapor ""%1"" (açılış)';it = 'Report ""%1"" (apertura)';de = 'Bericht ""%1"" (Eröffnung)'"), UpdatedDescription);
	
	MeasurementUpdating = Cache.MeasurementsTable.Add();
	MeasurementUpdating.OldName     = OldKey     + ".Generation";
	MeasurementUpdating.UpdatedName = UpdatedKey + ".Generation";
	MeasurementUpdating.UpdatedDescription = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Отчет ""%1"" (формирование)'; en = 'Report ""%1"" (generation)'; pl = 'Raport ""%1"" (tworzenie)';es_ES = 'Informe ""%1"" (generar)';es_CO = 'Informe ""%1"" (generar)';tr = 'Rapor ""%1"" (oluşturma)';it = 'Report ""%1"" (generazione)';de = 'Bericht ""%1"" (Formation)'"), UpdatedDescription);
	
	MeasurementUpdating = Cache.MeasurementsTable.Add();
	MeasurementUpdating.OldName     = OldKey     + ".Settings";
	MeasurementUpdating.UpdatedName = UpdatedKey + ".Settings";
	MeasurementUpdating.UpdatedDescription = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Отчет ""%1"" (настройки)'; en = 'Report ""%1"" (settings)'; pl = 'Raport ""%1"" (ustawienia)';es_ES = 'Informe ""%1"" (ajustes)';es_CO = 'Informe ""%1"" (ajustes)';tr = 'Rapor ""%1"" (ayarlar)';it = 'Report ""%1"" (impostazioni)';de = 'Bericht ""%1"" (Einstellungen)'"), UpdatedDescription);
EndProcedure

// Table template to update measurements.
Function MeasurementsTable()
	Result = New ValueTable;
	Result.Columns.Add("OldName", TypesDetailsString(150));
	Result.Columns.Add("UpdatedName", TypesDetailsString(150));
	Result.Columns.Add("UpdatedDescription", TypesDetailsString(150));
	Return Result;
EndFunction

// Writing report option parameters to the register.
//
// Parameter values:
//   ValueStorage (Structure) - Cached parameters:
//       * FunctionalOptionsTable - ValueTable - Options and predefined report options names.
//           ** Report - CatalogRef.MetadataObjectIDs - a report reference.
//           ** PredefinedOption - CatalogRef.PredefinedReportOptions - The option reference.
//           ** FunctionalOptionName - String - a functional option name.
//       * ReportsWithSettings - Array from CatalogRef.MetadataObjectIDs - reports whose object 
//           module contains procedures of deep integration with the common report form.
//
Procedure WriteReportOptionsParameters(Cache)
	If Cache.Mode = "ExtensionsCommonData" AND Not ValueIsFilled(SessionParameters.ExtensionsVersion) Then
		Return; // The update is not required.
	EndIf;
	ProcedurePresentation = NStr("ru = 'Запись неразделенного кэша в регистр'; en = 'Write undivided cache to register'; pl = 'Zapis niepodzielonej pamięci podręcznej do rejestru';es_ES = 'Guardar caché no dividido en el registro';es_CO = 'Guardar caché no dividido en el registro';tr = 'Karşılıksız önbelleği sicile kaydetme';it = 'Scrittura della cache indivisa nel registro';de = 'Schreiben eines ungeteilten Caches in ein Register'");
	WriteProcedureStartToLog(ProcedurePresentation);
	
	Cache.FunctionalOptionsTable.Sort("Report, PredefinedVariant, FunctionalOptionName");
	Cache.ReportsWithSettingsList.SortByValue();
	
	NewValue = New Structure;
	NewValue.Insert("FunctionalOptionsTable", Cache.FunctionalOptionsTable);
	NewValue.Insert("ReportsWithSettings", Cache.ReportsWithSettingsList.UnloadValues());
	
	FullSubsystemName = ReportsOptionsClientServer.FullSubsystemName();
	
	If Cache.Mode = "ConfigurationCommonData" Then
		PreviousValue = StandardSubsystemsServer.ApplicationParameter(FullSubsystemName);
		If Common.ValueToXMLString(NewValue) <> Common.ValueToXMLString(PreviousValue) Then
			StandardSubsystemsServer.SetApplicationParameter(FullSubsystemName, NewValue);
		EndIf;
	ElsIf Cache.Mode = "ExtensionsCommonData" Then
		StandardSubsystemsServer.SetExtensionParameter(FullSubsystemName, NewValue);
	EndIf;
	
	WriteProcedureCompletionToLog(ProcedurePresentation);
EndProcedure

// Write the PredefinedExtensionsVersionsReportsOptions register.
//
// Value to save:
//   ValueStorage (Structure) - Cached parameters:
//       * FunctionalOptionsTable - ValueTable - Options and predefined report options names.
//           ** Report - CatalogRef.ExtensionObjectIDs - a report reference.
//           ** PredefinedOption - CatalogRef.PredefinedReportOptionsOfExtensions - The option reference.
//           ** FunctionalOptionName - String - a functional option name.
//       * ReportsWithSettings - Array from CatalogRef.ExtensionObjectIDs - reports whose object 
//           module contains procedures of deep integration with the common report form.
//
Procedure RecordCurrentExtensionsVersion(Cache)
	If Not ValueIsFilled(SessionParameters.ExtensionsVersion) Then
		Return; // The update is not required.
	EndIf;
	
	ProcedurePresentation = NStr("ru = 'Запись регистра версий расширений'; en = 'Write extension version register'; pl = 'Zapis rejestru wersji rozszerzeń';es_ES = 'Guardar el registro en de las versiones de las extensiones';es_CO = 'Guardar el registro en de las versiones de las extensiones';tr = 'Uzantı sürüm kaydı';it = 'Scrittura del registro della versione di estensione';de = 'Schreiben des Registers der Erweiterungsversionen'");
	WriteProcedureStartToLog(ProcedurePresentation);
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	PredefinedExtensions.Ref AS Variant,
	|	PredefinedExtensions.Report,
	|	PredefinedExtensions.VariantKey
	|FROM
	|	Catalog.PredefinedExtensionsReportsOptions AS PredefinedExtensions
	|WHERE
	|	PredefinedExtensions.DeletionMark = FALSE";
	
	Table = Query.Execute().Unload();
	Dimensions = New Structure("ExtensionsVersion", SessionParameters.ExtensionsVersion);
	Resources = New Structure;
	Set = InformationRegisters.PredefinedExtensionsVersionsReportsOptions.Set(Table, Dimensions, Resources, True);
	InfobaseUpdate.WriteRecordSet(Set, True);
	
	WriteProcedureCompletionToLog(ProcedurePresentation);
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Updating an infobase / Migrating to revision 2.1.

// Changing the structure of storing settings by sections to MOID catalog references.
//   The procedure is called only for internal report options.
//
Procedure Edition21ArrangeSettingsBySections(OptionObject)
	
	Count = OptionObject.Placement.Count();
	For Number = 1 To Count Do
		ReverseIndex = Count - Number;
		TableRow = OptionObject.Placement[ReverseIndex];
		
		If ValueIsFilled(TableRow.Subsystem) Then
			Continue; // Filling is not required.
		EndIf;
		
		If Not ValueIsFilled(TableRow.DeleteSubsystem) Then
			OptionObject.Placement.Delete(TableRow);
			Continue; // Filling is not possible.
		EndIf;
		
		SubsystemFullName = "Subsystem." + StrReplace(TableRow.DeleteSubsystem, "\", ".Subsystem.");
		SubsystemMetadata = Metadata.FindByFullName(SubsystemFullName);
		If SubsystemMetadata = Undefined Then
			OptionObject.Placement.Delete(TableRow);
			Continue; // Filling is not possible.
		EndIf;
		
		SubsystemRef = Common.MetadataObjectID(SubsystemMetadata);
		If Not ValueIsFilled(SubsystemRef) Or TypeOf(SubsystemRef) = Type("String") Then
			OptionObject.Placement.Delete(TableRow);
			Continue; // Filling is not possible.
		EndIf;
		
		TableRow.Use = True;
		TableRow.Subsystem = SubsystemRef;
		TableRow.DeleteSubsystem = "";
		TableRow.DeleteName = "";
		
	EndDo;
	
EndProcedure

// Filling in the ReportOptionsSettings register.
//   The procedure is called only for internal report options.
//
Procedure Edition21MoveUserSettingsToRegister(OptionObject)
	SubsystemsTable = OptionObject.Placement.Unload(New Structure("Use", True));
	SubsystemsTable.GroupBy("Subsystem");
	
	UsersTable = OptionObject.DeleteQuickAccessExceptions.Unload();
	UsersTable.Columns.DeleteUser.Name = "User";
	UsersTable.GroupBy("User");
	
	SettingsPackage = New ValueTable;
	SettingsPackage.Columns.Add("Subsystem",   SubsystemsTable.Columns.Subsystem.ValueType);
	SettingsPackage.Columns.Add("User", UsersTable.Columns.User.ValueType);
	SettingsPackage.Columns.Add("Visible",    New TypeDescription("Boolean"));
	
	For Each RowSubsystem In SubsystemsTable Do
		For Each UserString In UsersTable Do
			Setting = SettingsPackage.Add();
			Setting.Subsystem   = RowSubsystem.SectionOrGroup;
			Setting.User = UserString.User;
			Setting.Visible    = Not OptionObject.VisibleByDefault;
		EndDo;
	EndDo;
	
	Dimensions = New Structure("Variant", OptionObject.Ref);
	Resources   = New Structure("QuickAccess", False);
	InformationRegisters.ReportOptionsSettings.WriteSettingsPackage(SettingsPackage, Dimensions, Resources, True);
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Operations with the subsystem tree from forms.

// Adds conditional appearance items of the subsystem tree.
Procedure SetSubsystemsTreeConditionalAppearance(Form) Export
	
	Form.Items.SubsystemsTreeImportance.ChoiceList.Add(ReportsOptionsClientServer.ImportantPresentation());
	Form.Items.SubsystemsTreeImportance.ChoiceList.Add(ReportsOptionsClientServer.SeeAlsoPresentation());
	
	Item = Form.ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Form.Items.SubsystemsTree.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("SubsystemsTree.Priority");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = "";

	Item.Appearance.SetParameterValue("ReadOnly", True);
	
	Item = Form.ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Form.Items.SubsystemsTreeUsage.Name);
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Form.Items.SubsystemsTreeImportance.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("SubsystemsTree.Priority");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = "";

	Item.Appearance.SetParameterValue("Show", False);
	
EndProcedure

// Generates a subsystem tree according to base option data.
Function SubsystemsTreeGenerate(Form, OptionBasis) Export
	// Blank tree without settings.
	Prototype = Form.FormAttributeToValue("SubsystemsTree", Type("ValueTree"));
	SubsystemsTree = ReportsOptionsCached.CurrentUserSubsystems().Copy();
	For Each PrototypeColumn In Prototype.Columns Do
		If SubsystemsTree.Columns.Find(PrototypeColumn.Name) = Undefined Then
			SubsystemsTree.Columns.Add(PrototypeColumn.Name, PrototypeColumn.ValueType);
		EndIf;
	EndDo;
	
	// Parameters.
	Context = New Structure("SubsystemsTree");
	Context.SubsystemsTree = SubsystemsTree;
	
	// Placement configured by the administrator.
	Subsystems = New Array;
	For Each PlacementRow In OptionBasis.Placement Do
		Subsystems.Add(PlacementRow.Subsystem);
		SubsystemsTreeRegisterSubsystemsSettings(Context, PlacementRow, PlacementRow.Use);
	EndDo;
	
	// Placement predefined by the developer.
	QueryText = 
	"SELECT
	|	Placement.Ref,
	|	Placement.LineNumber,
	|	Placement.Subsystem,
	|	Placement.Important,
	|	Placement.SeeAlso
	|FROM
	|	Catalog.PredefinedReportsOptions.Placement AS Placement
	|WHERE
	|	Placement.Ref = &Ref
	|	AND NOT Placement.Subsystem IN (&Subsystems)";
	
	If TypeOf(OptionBasis.PredefinedVariant) = Type("CatalogRef.PredefinedExtensionsReportsOptions") Then
		QueryText = StrReplace(QueryText, "PredefinedReportsOptions", "PredefinedExtensionsReportsOptions");
	EndIf;
	
	Query = New Query(QueryText);
	Query.SetParameter("Ref", OptionBasis.PredefinedVariant);
	// Do not read subsystem settings predefined by the administrator.
	Query.SetParameter("Subsystems", Subsystems);
	PredefinedItemPlacement = Query.Execute().Unload();
	For Each PlacementRow In PredefinedItemPlacement Do
		SubsystemsTreeRegisterSubsystemsSettings(Context, PlacementRow, True);
	EndDo;
	
	Return Context.SubsystemsTree;
EndFunction

// Adds a subsystem to the tree.
Procedure SubsystemsTreeRegisterSubsystemsSettings(Context, PlacementRow, Usage)
	FoundItems = Context.SubsystemsTree.Rows.FindRows(New Structure("Ref", PlacementRow.Subsystem), True);
	If FoundItems.Count() = 0 Then
		Return;
	EndIf;
	
	TreeRow = FoundItems[0];
	
	If PlacementRow.Important Then
		TreeRow.Importance = ReportsOptionsClientServer.ImportantPresentation();
	ElsIf PlacementRow.SeeAlso Then
		TreeRow.Importance = ReportsOptionsClientServer.SeeAlsoPresentation();
	Else
		TreeRow.Importance = "";
	EndIf;
	TreeRow.Use = Usage;
EndProcedure

// Saves placement settings changed by the user to the tabular section of the report option.
//
// Parameters:
//   OptionObject - CatalogObject.ReportOptions, FormDataStructure - a report option object.
//   ChangedSubsystems - Array - an array of value tree rows, which contains changed placement settings.
//
Procedure SubsystemsTreeWrite(OptionObject, ChangedSubsystems) Export
	
	For Each Subsystem In ChangedSubsystems Do
		TabularSectionRow = OptionObject.Placement.Find(Subsystem.Ref, "Subsystem");
		If TabularSectionRow = Undefined Then
			// The variant placement setting must be registered unconditionally (even if the Usage flag is disabled)
			// - than this setting will replace the predefined one (from the shared catalog).
			TabularSectionRow = OptionObject.Placement.Add();
			TabularSectionRow.Subsystem = Subsystem.Ref;
		EndIf;
		
		If Subsystem.Use = 0 Then
			TabularSectionRow.Use = False;
		ElsIf Subsystem.Use = 1 Then
			TabularSectionRow.Use = True;
		Else
			// Leave as it is
		EndIf;
		
		If Subsystem.Importance = ReportsOptionsClientServer.ImportantPresentation() Then
			TabularSectionRow.Important  = True;
			TabularSectionRow.SeeAlso = False;
		ElsIf Subsystem.Importance = ReportsOptionsClientServer.SeeAlsoPresentation() Then
			TabularSectionRow.Important  = False;
			TabularSectionRow.SeeAlso = True;
		Else
			TabularSectionRow.Important  = False;
			TabularSectionRow.SeeAlso = False;
		EndIf;
	EndDo;
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Generating presentations of fields, parameters, and filters for search.

// The function is called from the OnWrite option event. Some checks are performed before the call.
Function IndexSchemaContent(OptionObject) Export
	AdditionalProperties = OptionObject.AdditionalProperties;
	WritingRequired = False;
	
	// In some cases, it is known in advance that the settings are already indexed.
	IndexSchema = CommonClientServer.StructureProperty(AdditionalProperties, "IndexSchema");
	If IndexSchema = False Then
		Return WritingRequired; // Filling is not required.
	EndIf;
	CheckHash = True;
	If IndexSchema = True Then
		CheckHash = False;
	EndIf;
	
	// Manual indexing from option data.
	FillFields = Left(OptionObject.FieldDescriptions, 1) <> "#";
	FillFilters = Left(OptionObject.FilterParameterDescriptions, 1) <> "#";
	If Not FillFields AND Not FillFilters Then
		Return WritingRequired; // Filling is not required.
	EndIf;
	
	// Getting a report object, DCS settings, and an option.
	IsPredefined = TypeOf(OptionObject) = Type("CatalogObject.PredefinedReportsOptions")
		Or TypeOf(OptionObject) = Type("CatalogObject.PredefinedExtensionsReportsOptions")
		Or Not OptionObject.Custom;
	
	// Preset search settings.
	SearchSettings = CommonClientServer.StructureProperty(AdditionalProperties, "SearchSettings");
	If SearchSettings <> Undefined Then
		If FillFields AND ValueIsFilled(SearchSettings.FieldDescriptions) Then
			OptionObject.FieldDescriptions = "#" + TrimAll(SearchSettings.FieldDescriptions);
			FillFields = False;
			WritingRequired = True;
		EndIf;
		If FillFilters AND ValueIsFilled(SearchSettings.FilterParameterDescriptions) Then
			OptionObject.FilterParameterDescriptions = "#" + TrimAll(SearchSettings.FilterParameterDescriptions);
			FillFilters = False;
			WritingRequired = True;
		EndIf;
		If ValueIsFilled(SearchSettings.Keywords) Then
			OptionObject.Keywords = "#" + TrimAll(SearchSettings.Keywords);
			WritingRequired = True;
		EndIf;
		If Not FillFields AND Not FillFilters Then
			Return WritingRequired; // Filling is completed, write an object.
		EndIf;
	EndIf;
	
	// In some scenarios, an object can be already cached in additional properties.
	ReportObject = CommonClientServer.StructureProperty(AdditionalProperties, "ReportObject");
	
	// When a report object is not cached, attach an object in the regular way.
	If ReportObject = Undefined Then
		Attachment = AttachReportObject(OptionObject.Report, False);
		If Attachment.Success Then
			ReportObject = Attachment.Object;
		Else
			ReportObject = "";
			WriteToLog(EventLogLevel.Error, Attachment.ErrorText, OptionObject.Ref);
		EndIf;
		AdditionalProperties.Insert("ReportObject", ReportObject);
	EndIf;
	If ReportObject = "" Then
		Return WritingRequired; // An issue occurred during report attachement.
	EndIf;
	
	// Extracting template texts is possible only once a report object is received.
	If FillFields AND SearchSettings <> Undefined AND ValueIsFilled(SearchSettings.TemplatesNames) Then
		OptionObject.FieldDescriptions = "#" + ExtractTemplateText(ReportObject, SearchSettings.TemplatesNames);
		WritingRequired = true;
		FillFields = False;
		If Not FillFields AND Not FillFilters Then
			Return WritingRequired; // Filling is completed, write an object.
		EndIf;
	EndIf;
	
	// The composition schema that will be a basis for report execution.
	DCSchema = ReportObject.DataCompositionSchema;
	
	// If a report is not on DCS, presentations are not filled or filled by applied features.
	If DCSchema = Undefined Then
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Для варианта ""%1"" отчета ""%2"" не заполнены настройки поиска:
			|Наименования полей или Наименования параметров и отборов.'; 
			|en = 'The following search settings are not filled in for the ""%1"" option of the ""%2"" repot:
			|Field names or Names of parameters and filters.'; 
			|pl = 'Dla wariantu ""%1"" raportu ""%2"" nie wypełnione ustawienia wyszukiwania: 
			|Nazwa pól lub Nazwa parametrów i selekcji.';
			|es_ES = 'Los ajustes de búsqueda no están rellenados para la variante ""%1"" del informe ""%2"":
			|Nombres de campos o Nombres de parámetros y selecciones.';
			|es_CO = 'Los ajustes de búsqueda no están rellenados para la variante ""%1"" del informe ""%2"":
			|Nombres de campos o Nombres de parámetros y selecciones.';
			|tr = 'Arama ayarları ""%1"" raporunun ""%2"" seçeneği için doldurulmamıştır: 
			|alan adları veya parametreler ve filtreler.';
			|it = 'Le seguenti impostazioni di ricerca non sono compilate per la variante ""%1"" del report ""%2"":
			|Nomi campi o Nomi parametri e filtri.';
			|de = 'Bei der Option ""%1"" des Berichts ""%2"" werden die Sucheinstellungen nicht ausgefüllt:
			|Feldnamen oder Parameternamen und Auswahlmöglichkeiten.'"),
			OptionObject.VariantKey,
			OptionObject.Report);
		If IsPredefined Then
			ErrorText = ErrorText + Chars.LF
				+ NStr("ru = 'Подробнее - см. процедуру ""CustomizeReportOptions"" модуля ""ReportOptionsOverridable"".'; en = 'For more information, see the ""CustomizeReportOptions"" procedure of the ""ReportOptionsOverridable"" module.'; pl = 'Więcej - patrz ""CustomizeReportOptions"" procedurę ""ReportOptionsOverridable"" modułu.';es_ES = 'Más véase el procedimiento ""CustomizeReportOptions"" del módulo ""ReportOptionsOverridable"".';es_CO = 'Más véase el procedimiento ""CustomizeReportOptions"" del módulo ""ReportOptionsOverridable"".';tr = 'Daha fazla - bkz. ""ReportOptionsOverridable"" modülün ""CustomizeReportOptions"" prosedürü';it = 'Per ulteriori informazioni consultare la procedura ""CustomizeReportOptions"" del modulo ""ReportOptionsOverridable"".';de = 'Weitere Informationen finden Sie in der Prozedur ""CustomizeReportOptions"" des Moduls ""ReportOptionsOverridable"".'");
		EndIf;
		WriteToLog(EventLogLevel.Information, ErrorText, OptionObject.Ref);
		
		Return WritingRequired; // An error occurred.
	EndIf;
	
	// Reading settings from the passed parameters.
	DCSettings = CommonClientServer.StructureProperty(AdditionalProperties, "DCSettings");
	
	// Reading settings from the schema.
	If TypeOf(DCSettings) <> Type("DataCompositionSettings") Then
		DCSettingsOption = DCSchema.SettingVariants.Find(OptionObject.VariantKey);
		If DCSettingsOption <> Undefined Then
			DCSettings = DCSettingsOption.Settings;
		EndIf;
	EndIf;
	
	// Read settings from option data.
	If TypeOf(DCSettings) <> Type("DataCompositionSettings")
		AND TypeOf(OptionObject) = Type("CatalogObject.ReportsOptions") Then
		Try
			DCSettings = OptionObject.Settings.Get();
		Except
			MessageTemplate = NStr("ru = 'Не удалось прочитать настройки пользовательского варианта отчета:
				|%1'; 
				|en = 'Cannot read user report option settings: 
				|%1'; 
				|pl = 'Nie udało się odczytać ustawienia wariantu raportu użytkownika: 
				|%1';
				|es_ES = 'No se ha podido leer los ajustes de la variante de usuario del informe:
				|%1';
				|es_CO = 'No se ha podido leer los ajustes de la variante de usuario del informe:
				|%1';
				|tr = 'Raporun kullanıcı seçeneğinin ayarları okunamadı: 
				|%1';
				|it = 'Impossibile leggere le impostazioni della variante utente del report: 
				|%1';
				|de = 'Es war nicht möglich, die Einstellungen der benutzerdefinierten Variante des Berichts zu lesen:
				|%1'");
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageTemplate,
				DetailErrorDescription(ErrorInfo()));
			WriteToLog(EventLogLevel.Error, MessageText, OptionObject.Ref);
			Return WritingRequired; // An error occurred.
		EndTry;
	EndIf;
	
	// Last check.
	If TypeOf(DCSettings) <> Type("DataCompositionSettings") Then
		If TypeOf(OptionObject) = Type("CatalogObject.PredefinedReportsOptions")
			Or TypeOf(OptionObject) = Type("CatalogObject.PredefinedExtensionsReportsOptions") Then
			WriteToLog(EventLogLevel.Error, 
				StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = 'Не удалось прочитать настройки предопределенного варианта отчета ""%1"".'; en = 'Cannot read settings of the predefined option of report ""%1"".'; pl = 'Nie udało się odczytać ustawiania predefiniowanego wariantu raportu ""%1"".';es_ES = 'No se ha podido leer los ajustes de la variante predeterminada del informe ""%1"".';es_CO = 'No se ha podido leer los ajustes de la variante predeterminada del informe ""%1"".';tr = 'Raporun ön tanımlanmış seçeneğinin ayarları okunamadı: %1';it = 'Impossibile leggere le impostazioni della variante predefinita del report ""%1"".';de = 'Es war nicht möglich, die Einstellungen der vordefinierten Version des Berichts ""%1"" zu lesen.'"), OptionObject.MeasurementsKey),
				OptionObject.Ref);
		EndIf;
		Return WritingRequired; // An error occurred.
	EndIf;
	
	HashOfTheseSettings = Common.CheckSumString(Common.ValueToXMLString(DCSettings));
	If CheckHash AND OptionObject.SettingsHash = HashOfTheseSettings Then
		Return WritingRequired; // Settings did not change.
	EndIf;
	WritingRequired = true;
	OptionObject.SettingsHash = HashOfTheseSettings;
	
	// The code describes the link between data composition settings and data composition schema.
	DCSettingsComposer = ReportObject.SettingsComposer;
	
	// Initialize the composer and its settings (Settings) with the source of available setting.
	DCSettingsComposer.Initialize(New DataCompositionAvailableSettingsSource(DCSchema));
	
	// Import settings to the composer and clear user settings.
	ReportsClientServer.LoadSettings(DCSettingsComposer, DCSettings);
	
	If FillFields Then
		// Transforming all settings of automatic grouping into field sets.
		//   See "DataCompositionAutoSelectedField", "DataCompositionAutoGroupField",
		//   "DataCompositionAutoOrderItem" in Syntax Assistant.
		DCSettingsComposer.ExpandAutoFields();
		
		OptionObject.FieldDescriptions = GenerateFiledsPresentations(DCSettingsComposer);
	EndIf;
	
	If FillFilters Then
		OptionObject.FilterParameterDescriptions = GenerateParametersAndFiltersPresentations(DCSettingsComposer);
	EndIf;
	
	Return WritingRequired;
EndFunction

// Presentations of groups and fields from DCS.
Function GenerateFiledsPresentations(DCSettingsComposer)
	Result = New Array;
	
	AddItemsToArrayFromRowWithSeparators(Result, String(DCSettingsComposer.Settings.Selection));
	
	CollectionsArray = New Array;
	CollectionsArray.Add(DCSettingsComposer.Settings.Structure);
	While CollectionsArray.Count() > 0 Do
		Collection = CollectionsArray[0];
		CollectionsArray.Delete(0);
		
		For Each Setting In Collection Do
			
			If TypeOf(Setting) = Type("DataCompositionNestedObjectSettings") Then
				If Not Setting.Use Then
					Continue;
				EndIf;
				Setting = Setting.Settings;
			EndIf;
			
			AddItemsToArrayFromRowWithSeparators(Result, String(Setting.Selection));
			
			If TypeOf(Setting) = Type("DataCompositionSettings") Then
				CollectionsArray.Add(Setting.Structure);
			ElsIf TypeOf(Setting) = Type("DataCompositionGroup") Then
				If Not Setting.Use Then
					Continue;
				EndIf;
				CollectionsArray.Add(Setting.Structure);
			ElsIf TypeOf(Setting) = Type("DataCompositionTable") Then
				If Not Setting.Use Then
					Continue;
				EndIf;
				CollectionsArray.Add(Setting.Rows);
			ElsIf TypeOf(Setting) = Type("DataCompositionTableGroup") Then
				If Not Setting.Use Then
					Continue;
				EndIf;
				CollectionsArray.Add(Setting.Structure);
			ElsIf TypeOf(Setting) = Type("DataCompositionChart") Then
				If Not Setting.Use Then
					Continue;
				EndIf;
				CollectionsArray.Add(Setting.Series);
				CollectionsArray.Add(Setting.Points);
			ElsIf TypeOf(Setting) = Type("DataCompositionChartGroup") Then
				If Not Setting.Use Then
					Continue;
				EndIf;
				CollectionsArray.Add(Setting.Structure);
			EndIf;
			
		EndDo;
		
	EndDo;
	
	StorageSeparator = ReportsOptionsClientServer.StorageSeparator();
	Return StrConcat(Result, StorageSeparator);
EndFunction

// Presentations of parameters and filters from DCS.
Function GenerateParametersAndFiltersPresentations(DCSettingsComposer)
	Result = New Array;
	
	DCSettings = DCSettingsComposer.Settings;
	
	Modes = DataCompositionSettingsItemViewMode;
	
	For Each UserSetting In DCSettingsComposer.UserSettings.Items Do
		SettingType = TypeOf(UserSetting);
		If SettingType = Type("DataCompositionSettingsParameterValue") Then
			IsFilter = False;
		ElsIf SettingType = Type("DataCompositionFilterItem") Then
			IsFilter = True;
		Else
			Continue;
		EndIf;
		
		If UserSetting.ViewMode = Modes.Inaccessible Then
			Continue;
		EndIf;
		
		ID = UserSetting.UserSettingID;
		
		CommonSetting = ReportsClientServer.GetObjectByUserID(DCSettings, ID);
		If CommonSetting = Undefined Then
			Continue;
		ElsIf UserSetting.ViewMode = Modes.Auto
			AND CommonSetting.ViewMode <> Modes.QuickAccess Then
			Continue;
		EndIf;
		
		PresentationStructure = New Structure("Presentation, UserSettingPresentation", "", "");
		FillPropertyValues(PresentationStructure, CommonSetting);
		If ValueIsFilled(PresentationStructure.UserSettingPresentation) Then
			ItemHeader = PresentationStructure.UserSettingPresentation;
		ElsIf ValueIsFilled(PresentationStructure.Presentation) Then
			ItemHeader = PresentationStructure.Presentation;
		Else
			AvailableSetting = ReportsClientServer.FindAvailableSetting(DCSettings, CommonSetting);
			If AvailableSetting <> Undefined AND ValueIsFilled(AvailableSetting.Title) Then
				ItemHeader = AvailableSetting.Title;
			Else
				ItemHeader = String(?(IsFilter, CommonSetting.LeftValue, CommonSetting.Parameter));
			EndIf;
		EndIf;
		
		ItemHeader = TrimAll(ItemHeader);
		If ItemHeader <> "" AND Result.Find(ItemHeader) = Undefined Then
			Result.Add(ItemHeader);
		EndIf;
		
	EndDo;
	
	StorageSeparator = ReportsOptionsClientServer.StorageSeparator();
	Return StrConcat(Result, StorageSeparator);
EndFunction

// Extracts text information from a template.
Function ExtractTemplateText(ReportObject, TemplatesNames)
	ExtractedText = "";
	If TypeOf(TemplatesNames) = Type("String") Then
		TemplatesNames = StrSplit(TemplatesNames, ",", False);
	EndIf;
	For Each TemplateName In TemplatesNames Do
		Template = ReportObject.GetTemplate(TrimAll(TemplateName));
		If TypeOf(Template) = Type("SpreadsheetDocument") Then
			Bottom = Template.TableHeight;
			Right = Template.TableWidth;
			CheckedCells = New Map;
			For ColumnNumber = 1 To Right Do
				For RowNumber = 1 To Bottom Do
					Cell = Template.Area(RowNumber, ColumnNumber, RowNumber, ColumnNumber);
					If CheckedCells.Get(Cell.Name) = Undefined Then
						CheckedCells.Insert(Cell.Name, True);
						If TypeOf(Cell) = Type("SpreadsheetDocumentRange") Then
							AreaText = TrimAll(Cell.Text);
							If AreaText <> "" Then
								ExtractedText = ExtractedText + Chars.LF + AreaText;
							EndIf;
						EndIf;
					EndIf;
				EndDo;
			EndDo;
		ElsIf TypeOf(Template) = Type("TextDocument") Then
			ExtractedText = ExtractedText + Chars.LF + TrimAll(Template.GetText());
		EndIf;
	EndDo;
	ExtractedText = TrimL(ExtractedText);
	Return ExtractedText;
EndFunction

// Adds elements from the RowWithSeparators into Array if it does not have them.
Procedure AddItemsToArrayFromRowWithSeparators(Array, RowWithSeparators)
	RowWithSeparators = TrimAll(RowWithSeparators);
	If RowWithSeparators = "" Then
		Return;
	EndIf;
	Position = StrFind(RowWithSeparators, ",");
	While Position > 0 Do
		Substring = TrimR(Left(RowWithSeparators, Position - 1));
		If Substring <> "" AND Array.Find(Substring) = Undefined Then
			Array.Add(Substring);
		EndIf;
		RowWithSeparators = TrimL(Mid(RowWithSeparators, Position + 1));
		Position = StrFind(RowWithSeparators, ",");
	EndDo;
	If RowWithSeparators <> "" AND Array.Find(RowWithSeparators) = Undefined Then
		Array.Add(RowWithSeparators);
	EndIf;
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Reducing the number of user settings.

// The function is called from the OnWrite option event. Some checks are performed before the call.
Function ReduceQuickSettingsNumber(OptionObject, ReportObject)
	
	If OptionObject = Undefined Then
		Return False; // No option in the base. Filling is not required.
	EndIf;
	
	// The composition schema that will be a basis for report execution.
	DCSchema = ReportObject.DataCompositionSchema;
	If DCSchema = Undefined Then
		Return False; // Report is not in DCS. Filling is not required.
	EndIf;
	
	// Read settings from option data.
	DCSettings = OptionObject.Settings.Get();
	If TypeOf(DCSettings) <> Type("DataCompositionSettings") Then
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Обнаружены пустые настройки пользовательского варианта ""%1"" отчета ""%2"".'; en = 'Empty settings of user option ""%1"" of report ""%2"" are detected.'; pl = 'Wykryto puste ustawienia opcji użytkownika ""%1"" sprawozdania ""%2"".';es_ES = 'Configuraciones vacías de la opción de usuario ""%1"" del informe ""%2"" se han detectado.';es_CO = 'Configuraciones vacías de la opción de usuario ""%1"" del informe ""%2"" se han detectado.';tr = '""%1"" Seçeneğinin ""%2"" kullanıcı seçeneğinin boş ayarları algılandı.';it = 'Impostazioni vuote per la variante utente ""%1"" del report ""%2% sono state selezionate.';de = 'Leere Einstellungen der Benutzeroption ""%1"" des Berichts ""%2"" werden erkannt.'"), 
			OptionObject.VariantKey, OptionObject.Report);
		WriteToLog(EventLogLevel.Error, ErrorText, OptionObject.Ref);
		Return False; // An error occurred.
	EndIf;
	
	// The code describes the link between data composition settings and data composition schema.
	DCSettingsComposer = ReportObject.SettingsComposer;
	
	// Initialize the composer and its settings (Settings) with the source of available setting.
	DCSettingsComposer.Initialize(New DataCompositionAvailableSettingsSource(DCSchema));
	
	// Import settings to the composer and clear user settings.
	ReportsClientServer.LoadSettings(DCSettingsComposer, DCSettings);
	
	OutputConditions = New Structure;
	OutputConditions.Insert("UserSettingsOnly", True);
	OutputConditions.Insert("QuickOnly",          True);
	OutputConditions.Insert("CurrentDCNodeID", Undefined);
	
	ReportSettings = ReportFormSettings(OptionObject.Report, OptionObject.VariantKey, ReportObject);
	
	Information = ReportsServer.AdvancedInformationOnSettings(DCSettingsComposer, ReportSettings, ReportObject, OutputConditions);
	QuickSettings = Information.UserSettings.Copy(New Structure("OutputAllowed, Quick", True, True));
	If QuickSettings.Count() <= 2 Then
		ReportsServer.ClearAdvancedInformationOnSettings(Information);
		Return False; // Reducing the number is not required.
	EndIf;
	
	ToExclude = QuickSettings.FindRows(New Structure("ItemsType", "StandardPeriod"));
	For Each TableRow In ToExclude Do
		QuickSettings.Delete(TableRow);
	EndDo;
	
	Spent = ToExclude.Count();
	For Each TableRow In QuickSettings Do
		If Spent < 2 Then
			Spent = Spent + 1;
			Continue;
		EndIf;
		TableRow.DCOptionSetting.ViewMode = DataCompositionSettingsItemViewMode.Normal;
	EndDo;
	
	OptionObject.Settings = New ValueStorage(DCSettingsComposer.Settings);
	ReportsServer.ClearAdvancedInformationOnSettings(Information);
	
	Return True;
EndFunction

Function ReportFormSettings(ReportRef, OptionKey, ReportObject) Export
	ReportSettings = ReportsClientServer.GetDefaultReportSettings();
	
	ReportsWithSettings = ReportsOptionsCached.Parameters().ReportsWithSettings;
	If ReportsWithSettings.Find(ReportRef) = Undefined 
		AND (ReportObject = Undefined Or Metadata.Reports.Contains(ReportObject.Metadata()))Then
		Return ReportSettings;
	EndIf;
	
	If ReportObject = Undefined Then
		Attachment = AttachReportObject(ReportRef, False);
		If Attachment.Success Then
			ReportObject = Attachment.Object;
		Else
			Text = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Не удалось получить настройки отчета ""%1"":'; en = 'Cannot receive report settings ""%1"":'; pl = 'Nie udało się otrzymać ustawienia raportu ""%1"":';es_ES = 'No se puede recibir los ajustes del informe ""%1"".';es_CO = 'No se puede recibir los ajustes del informe ""%1"".';tr = '""%1"" raporun ayarları elde edilemedi:';it = 'Impossibile acquisire impostazioni del report ""%1"":';de = 'Die Berichtseinstellungen konnten nicht übernommen werden ""%1"":'") + Chars.LF + Attachment.ErrorText,
				ReportRef);
			WriteToLog(EventLogLevel.Information, Text, ReportRef);
			Return ReportSettings;
		EndIf;
	EndIf;
	
	Try
		ReportObject.DefineFormSettings(Undefined, OptionKey, ReportSettings);
	Except
		ReportSettings = ReportsClientServer.GetDefaultReportSettings();
	EndTry;
	
	If Not GlobalSettings().EditOptionsAllowed Then
		ReportSettings.EditOptionsAllowed = False;
	EndIf;
	
	Return ReportSettings;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Search.

// Whether it is possible to index report schema content.
Function SharedDataIndexingAllowed()
	Return Not Common.DataSeparationEnabled();
EndFunction

// Finds references by search parameters.
//   Highlights found places.
//
// Parameters:
//   SearchParameters - Structure - search conditions.
//       * SearchString - String - Optional.
//       * Author - CatalogRef.Users - Optional.
//       * Subsystems - Array from CatalogRef.MetadataObjectIDs - Optional.
//
// Returns:
//   Structure - when search by string is performed.
//       * References - Array from CatalogRef.ReportsOptions -
//           It is filled by the report options, whose data contains all required words.
//       * OptionsHighlight - Map - highlighting found words (if SearchString is specified).
//           ** Key - CatalogRef.ReportsOptions.
//           ** Value - Structure.
//               *** Ref - CatalogRef.ReportsOptions.
//               *** FieldDescriptions                    - String.
//               *** FilterAndParameterDescriptions       - String.
//               *** Keywords                        - String.
//               *** Details                             - String.
//               *** UserSettingsDescriptions - String.
//               *** WhereFound                           - Structure.
//                   **** FieldDescriptions                    - Number.
//                   **** FilterAndParameterDescriptions       - Number.
//                   **** Keywords                        - Number.
//                   **** Details                             - Number.
//                   **** UserSettingsDescriptions - Number.
//       * Subsystems - Array from CatalogRef.MetadataObjectIDs -
//           Filled in with subsystems whose names contain all words to search for.
//           All nested report options must be displayed for such subsystems.
//       * SubsystemsHighlight - Map - highlighting found words (if SearchString is specified).
//           ** Key - CatalogRef.ReportsOptions.
//           ** Value - Structure.
//               *** Ref - CatalogRef.MetadataObjectIDs.
//               *** SubsystemDescription - String.
//               *** AllWordsFound - Boolean.
//               *** FoundWords - Array.
//       * OptionsLinkedWithSubsystems - Map - report options and their subsystems.
//           Filled in when some words are found in option data, and other words are found in descriptions of its subsystems.
//           In this case, an option must be displayed in found subsystems only (it must not be displayed in other subsystems).
//           Applied in the report panel.
//           ** Key - CatalogRef.ReportsOptions - an option.
//           ** Value - Array From CatalogRef.MetadataObjectIDs - Subsystem.
//
Function FindLinks(SearchParameters) Export
	
	If SearchParameters.Property("SearchString") AND ValueIsFilled(SearchParameters.SearchString) Then
		HasSearchString = True;
	Else
		HasSearchString = False;
	EndIf;
	
	If SearchParameters.Property("Reports") AND ValueIsFilled(SearchParameters.Reports) Then
		HasFilterByReports = True;
	Else
		HasFilterByReports = False;
	EndIf;
	
	If SearchParameters.Property("Subsystems") AND ValueIsFilled(SearchParameters.Subsystems) Then
		HasFilterBySubsystems = True;
	Else
		HasFilterBySubsystems = False;
	EndIf;
	
	ExactFilterBySubsystems = HasFilterBySubsystems
		AND CommonClientServer.StructureProperty(SearchParameters, "ExactFilterBySubsystems", True);
	
	If SearchParameters.Property("ReportTypes") AND ValueIsFilled(SearchParameters.ReportTypes) Then
		HasFilterByReportTypes = True;
	Else
		HasFilterByReportTypes = False;
	EndIf;
	
	If SearchParameters.Property("OnlyItemsVisibleInReportPanel") AND SearchParameters.OnlyItemsVisibleInReportPanel = True Then
		HasFilterByVisibility = HasFilterBySubsystems; // Supported only when a filter by subsystems is specified.
	Else
		HasFilterByVisibility = False;
	EndIf;
	
	If SearchParameters.Property("GetSummaryTable") AND SearchParameters.GetSummaryTable = True Then
		GetSummaryTable = True;
	Else
		GetSummaryTable = False;
	EndIf;
	
	If SearchParameters.Property("DeletionMark") Then
		HasFilterByDeletionMark = SearchParameters.DeletionMark;
	Else
		HasFilterByDeletionMark = True;
	EndIf;
	
	If Not HasFilterBySubsystems AND Not HasSearchString AND Not HasFilterByReportTypes AND Not HasFilterByReports Then
		Return Undefined;
	EndIf;
	
	Query = New Query;
	
	AuthorsReadRight = AccessRight("Read", Metadata.Catalogs.Users);
	
	CurrentUser = Users.AuthorizedUser();
	
	If HasFilterByReports Then
		FilterByReports = SearchParameters.Reports;
		SearchParameters.Insert("DIsabledApplicationOptions", DisabledReportOptions(FilterByReports));
	Else
		SearchParameters.Insert("DIsabledApplicationOptions", ReportsOptionsCached.DIsabledApplicationOptions());
		SearchParameters.Insert("UserReports", CurrentUserReports());
		FilterByReports = SearchParameters.UserReports;
	EndIf;
	
	Query.SetParameter("CurrentUser",          CurrentUser);
	Query.SetParameter("UserReports",           FilterByReports);
	Query.SetParameter("DIsabledApplicationOptions", SearchParameters.DIsabledApplicationOptions);
	Query.SetParameter("ExtensionsVersion",             SessionParameters.ExtensionsVersion);
	Query.SetParameter("ReportTypeExtension",          Enums.ReportTypes.Extension);
	Query.SetParameter("NoFilterByDeletionMark", NOT HasFilterByDeletionMark);
	
	If HasFilterBySubsystems Or HasSearchString Then
		QueryText =
		"SELECT ALLOWED
		|	ReportsOptions.Ref,
		|	ReportsOptions.Parent AS Parent,
		|	ReportsOptions.Description AS OptionDescription,
		|	ReportsOptions.Author AS Author,
		|	ReportsOptions.AvailableToAuthorOnly AS AvailableToAuthorOnly,
		|	CAST(ReportsOptions.Author.Description AS STRING(1000)) AS AuthorPresentation,
		|	ReportsOptions.Report AS Report,
		|	ReportsOptions.VariantKey AS VariantKey,
		|	ReportsOptions.ReportType AS ReportType,
		|	ReportsOptions.Custom AS Custom,
		|	ReportsOptions.PredefinedVariant AS PredefinedVariant,
		|	CASE
		|		WHEN SUBSTRING(ReportsOptions.FieldDescriptions, 1, 1) = """"
		|			THEN CAST(ISNULL(ConfigurationOptions.FieldDescriptions, ExtensionOptions.FieldDescriptions) AS STRING(1000))
		|		ELSE CAST(ReportsOptions.FieldDescriptions AS STRING(1000))
		|	END AS FieldDescriptions,
		|	CASE
		|		WHEN SUBSTRING(ReportsOptions.FilterParameterDescriptions, 1, 1) = """"
		|			THEN CAST(ISNULL(ConfigurationOptions.FilterParameterDescriptions, ExtensionOptions.FilterParameterDescriptions) AS STRING(1000))
		|		ELSE CAST(ReportsOptions.FilterParameterDescriptions AS STRING(1000))
		|	END AS FilterParameterDescriptions,
		|	CASE
		|		WHEN SUBSTRING(ReportsOptions.Keywords, 1, 1) = """"
		|			THEN CAST(ISNULL(ConfigurationOptions.Keywords, ExtensionOptions.Keywords) AS STRING(1000))
		|		ELSE CAST(ReportsOptions.Keywords AS STRING(1000))
		|	END AS Keywords,
		|	CASE
		|		WHEN SUBSTRING(ReportsOptions.Details, 1, 1) = """"
		|			THEN CAST(ISNULL(ConfigurationOptions.Details, ExtensionOptions.Details) AS STRING(1000))
		|		ELSE CAST(ReportsOptions.Details AS STRING(1000))
		|	END AS Details,
		|	CASE
		|		WHEN ReportsOptions.Custom
		|			THEN ReportsOptions.InteractiveSetDeletionMark
		|		WHEN ReportsOptions.ReportType = &ReportTypeExtension
		|			THEN AvailableExtensionOptions.Variant IS NULL
		|		ELSE ISNULL(ConfigurationOptions.DeletionMark, ReportsOptions.DeletionMark)
		|	END AS DeletionMark,
		|	ReportsOptions.VisibleByDefault AS VisibleByDefault
		|INTO Variants
		|FROM
		|	Catalog.ReportsOptions AS ReportsOptions
		|		LEFT JOIN Catalog.PredefinedReportsOptions AS ConfigurationOptions
		|		ON ReportsOptions.PredefinedVariant = ConfigurationOptions.Ref
		|		LEFT JOIN Catalog.PredefinedExtensionsReportsOptions AS ExtensionOptions
		|		ON ReportsOptions.PredefinedVariant = ExtensionOptions.Ref
		|		LEFT JOIN InformationRegister.PredefinedExtensionsVersionsReportsOptions AS AvailableExtensionOptions
		|		ON ReportsOptions.PredefinedVariant = AvailableExtensionOptions.Variant
		|			AND (AvailableExtensionOptions.ExtensionsVersion = &ExtensionsVersion)
		|WHERE
		|	ReportsOptions.ReportType IN(&ReportTypes)
		|	AND ReportsOptions.Report IN(&UserReports)
		|	AND NOT ReportsOptions.PredefinedVariant IN (&DIsabledApplicationOptions)
		|	AND &ShowPersonalReportsOptionsByOtherAuthors
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	ISNULL(OptionsPlacement.Ref, PlacementPredefined.Ref) AS Ref,
		|	ISNULL(OptionsPlacement.Subsystem, PlacementPredefined.Subsystem) AS Subsystem,
		|	ISNULL(OptionsPlacement.SubsystemDescription, PlacementPredefined.SubsystemDescription) AS SubsystemDescription,
		|	ISNULL(OptionsPlacement.Use, TRUE) AS Use,
		|	CASE
		|		WHEN OptionsPlacement.Ref IS NULL
		|			THEN TRUE
		|		ELSE FALSE
		|	END AS ThisIsDeveloperSettingItem
		|INTO PlacementAll
		|FROM
		|	(SELECT
		|		ReportsOptions.Ref AS Ref,
		|		OptionsPlacement.Use AS Use,
		|		OptionsPlacement.Subsystem AS Subsystem,
		|		CASE
		|			WHEN OptionsPlacement.Subsystem.FullName = ""Subsystems""
		|				THEN &DesktopDescription
		|			ELSE OptionsPlacement.Subsystem.Synonym
		|		END AS SubsystemDescription
		|	FROM
		|		Variants AS ReportsOptions
		|			INNER JOIN Catalog.ReportsOptions.Placement AS OptionsPlacement
		|			ON (ReportsOptions.DeletionMark = FALSE OR &NoFilterByDeletionMark)
		|				AND ReportsOptions.Ref = OptionsPlacement.Ref
		|				AND (OptionsPlacement.Subsystem IN (&SubsystemsArray))) AS OptionsPlacement
		|		FULL JOIN (SELECT
		|			ReportsOptions.Ref AS Ref,
		|			ConfigurationPlacement.Subsystem AS Subsystem,
		|			CASE
		|				WHEN ConfigurationPlacement.Subsystem.FullName = ""Subsystems""
		|					THEN &DesktopDescription
		|				ELSE ConfigurationPlacement.Subsystem.Synonym
		|			END AS SubsystemDescription
		|		FROM
		|			Variants AS ReportsOptions
		|				INNER JOIN Catalog.PredefinedReportsOptions.Placement AS ConfigurationPlacement
		|				ON (ReportsOptions.Custom = FALSE)
		|					AND &ShowPersonalReportsOptionsByOtherAuthors
		|					AND (ReportsOptions.DeletionMark = FALSE OR &NoFilterByDeletionMark)
		|					AND ReportsOptions.PredefinedVariant = ConfigurationPlacement.Ref
		|					AND (ConfigurationPlacement.Subsystem IN (&SubsystemsArray))
		|		
		|		UNION ALL
		|		
		|		SELECT
		|			ReportsOptions.Ref,
		|			ExtensionsPlacement.Subsystem,
		|			CASE
		|				WHEN ExtensionsPlacement.Subsystem.FullName = ""Subsystems""
		|					THEN &DesktopDescription
		|				ELSE ExtensionsPlacement.Subsystem.Synonym
		|			END
		|		FROM
		|			Variants AS ReportsOptions
		|				INNER JOIN Catalog.PredefinedExtensionsReportsOptions.Placement AS ExtensionsPlacement
		|				ON (ReportsOptions.Custom = FALSE)
		|					AND ReportsOptions.PredefinedVariant = ExtensionsPlacement.Ref
		|					AND (ExtensionsPlacement.Subsystem IN (&SubsystemsArray))) AS PlacementPredefined
		|		ON OptionsPlacement.Ref = PlacementPredefined.Ref
		|			AND OptionsPlacement.Subsystem = PlacementPredefined.Subsystem
		|WHERE
		|	ISNULL(OptionsPlacement.Use, TRUE)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED DISTINCT
		|	PlacementAll.Ref AS Ref,
		|	PlacementAll.Subsystem AS Subsystem,
		|	PlacementAll.SubsystemDescription AS SubsystemDescription
		|INTO PlacementVisible
		|FROM
		|	PlacementAll AS PlacementAll
		|		LEFT JOIN InformationRegister.ReportOptionsSettings AS PersonalSettings
		|		ON PlacementAll.Subsystem = PersonalSettings.Subsystem
		|			AND PlacementAll.Ref = PersonalSettings.Variant
		|			AND (PersonalSettings.User = &CurrentUser)
		|		LEFT JOIN Variants AS Variants
		|		ON PlacementAll.Ref = Variants.Ref
		|WHERE
		|	ISNULL(PersonalSettings.Visible, Variants.VisibleByDefault)
		|	AND (Variants.DeletionMark = FALSE OR &NoFilterByDeletionMark)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	ReportsOptions.Ref AS Ref,
		|	ReportsOptions.Parent AS Parent,
		|	ReportsOptions.OptionDescription AS OptionDescription,
		|	ReportsOptions.AvailableToAuthorOnly AS AvailableToAuthorOnly,
		|	ReportsOptions.Author AS Author,
		|	ReportsOptions.AuthorPresentation AS AuthorPresentation,
		|	ReportsOptions.Report AS Report,
		|	ReportsOptions.Report.Name AS ReportName,
		|	ReportsOptions.VariantKey AS VariantKey,
		|	ReportsOptions.ReportType AS ReportType,
		|	ReportsOptions.Custom AS Custom,
		|	ReportsOptions.PredefinedVariant AS PredefinedVariant,
		|	ReportsOptions.FilterParameterDescriptions AS FilterParameterDescriptions,
		|	ReportsOptions.FieldDescriptions AS FieldDescriptions,
		|	ReportsOptions.Keywords AS Keywords,
		|	ReportsOptions.Details AS Details,
		|	Placement.Subsystem AS Subsystem,
		|	Placement.SubsystemDescription AS SubsystemDescription,
		|	UNDEFINED AS UserSettingKey,
		|	UNDEFINED AS UserSettingPresentation
		|FROM
		|	Variants AS ReportsOptions
		|		INNER JOIN PlacementVisible AS Placement
		|		ON ReportsOptions.Ref = Placement.Ref
		|WHERE
		|	(ReportsOptions.DeletionMark = FALSE OR &NoFilterByDeletionMark)
		|	AND &SearchForOptionsAndSubsystems
		|
		|UNION ALL
		|
		|SELECT DISTINCT
		|	UserSettings.Variant,
		|	Variants.Parent,
		|	UNDEFINED,
		|	UNDEFINED,
		|	UNDEFINED,
		|	UNDEFINED,
		|	UNDEFINED,
		|	UNDEFINED,
		|	UNDEFINED,
		|	UNDEFINED,
		|	UNDEFINED,
		|	UNDEFINED,
		|	UNDEFINED,
		|	UNDEFINED,
		|	UNDEFINED,
		|	UNDEFINED,
		|	UNDEFINED,
		|	UNDEFINED,
		|	UserSettings.UserSettingKey,
		|	UserSettings.Description
		|FROM
		|	Variants AS Variants
		|		INNER JOIN Catalog.UserReportSettings AS UserSettings
		|		ON Variants.Ref = UserSettings.Variant
		|WHERE
		|	UserSettings.User = &CurrentUser
		|	AND &SearchForUserSettings
		|	AND (UserSettings.DeletionMark = FALSE OR &NoFilterByDeletionMark)
		|	AND (Variants.DeletionMark = FALSE OR &NoFilterByDeletionMark)";
		
		If Not AuthorsReadRight Then
			QueryText = StrReplace(QueryText, "ReportsOptions.Author AS Author", "UNDEFINED AS Author");
			QueryText = StrReplace(QueryText, "CAST(ReportsOptions.Author.Description AS STRING(1000)) AS AuthorPresentation", "UNDEFINED AS AuthorPresentation");
		EndIf;
		
		If HasFilterByVisibility Then
			// No action required.
		Else
			// Deleting a temporary table for a filter by visibility.
			DeleteTemporaryTable(QueryText, "PlacementVisible");
			// Substituting a name of the temporary table to select from.
			QueryText = StrReplace(QueryText, "PlacementVisible", "PlacementAll");
		EndIf;
		
		If HasFilterByReportTypes Then
			Query.SetParameter("ReportTypes", SearchParameters.ReportTypes);
		Else
			// Deleting a filter by a report type.
			QueryText = StrReplace(
				QueryText,
				"ReportsOptions.ReportType IN(&ReportTypes)
				|	AND ",
				"");
		EndIf;
		
		If HasFilterBySubsystems Then
			If TypeOf(SearchParameters.Subsystems) = Type("Array") Then
				Query.SetParameter("SubsystemsArray", SearchParameters.Subsystems);
			Else
				SubsystemsArray = New Array;
				SubsystemsArray.Add(SearchParameters.Subsystems);
				Query.SetParameter("SubsystemsArray", SubsystemsArray);
			EndIf;
		Else
			// Deleting a filter by subsystems.
			QueryText = StrReplace(QueryText, "AND (OptionsPlacement.Subsystem IN (&SubsystemsArray))", "");
			QueryText = StrReplace(QueryText, "AND (ConfigurationPlacement.Subsystem IN (&SubsystemsArray))", "");
			QueryText = StrReplace(QueryText, "AND (ExtensionsPlacement.Subsystem IN (&SubsystemsArray))", "");
		EndIf;
		
		If HasSearchString AND Not ExactFilterBySubsystems Then
			// Information about placement is additional for the search, not the key one.
			If HasFilterByVisibility Then
				QueryText = StrReplace(
					QueryText,
					"INNER JOIN PlacementVisible AS Placement",
					"LEFT JOIN PlacementVisible AS Placement");
			Else
				QueryText = StrReplace(
					QueryText,
					"INNER JOIN PlacementAll AS Placement",
					"LEFT JOIN PlacementAll AS Placement");
			EndIf;
		EndIf;
		
		If HasSearchString Then
			SearchString = Upper(TrimAll(SearchParameters.SearchString));
			SearchTemplate = "";
			WordArray = ReportsOptionsClientServer.ParseSearchStringIntoWordArray(SearchString);
			For WordNumber = 1 To WordArray.Count() Do
				Word = WordArray[WordNumber-1];
				WordName = "Word" + Format(WordNumber, "NG=");
				Query.SetParameter(WordName, "%" + Word + "%");
				Template = "<TableName.FieldName> LIKE &" + WordName;
				If WordNumber = 1 Then
					SearchTemplate = Template;
				Else
					SearchTemplate = SearchTemplate + Chars.LF + "				Or " + Template;
				EndIf;
			EndDo;
			
			// Condition for option search.
			SearchForOptionsAndSubsystems = "("
				+ StrReplace(SearchTemplate, "<TableName.FieldName>", "ReportsOptions.OptionDescription")
				+ Chars.LF
				+ "				Or "
				+ StrReplace(SearchTemplate, "<TableName.FieldName>", "Placement.SubsystemDescription")
				+ Chars.LF
				+ "				Or "
				+ StrReplace(SearchTemplate, "<TableName.FieldName>", "ReportsOptions.FieldDescriptions")
				+ Chars.LF
				+ "				Or "
				+ StrReplace(SearchTemplate, "<TableName.FieldName>", "ReportsOptions.FilterParameterDescriptions")
				+ Chars.LF
				+ "				Or "
				+ StrReplace(SearchTemplate, "<TableName.FieldName>", "ReportsOptions.Details")
				+ Chars.LF
				+ "				Or "
				+ StrReplace(SearchTemplate, "<TableName.FieldName>", "ReportsOptions.Keywords");
			If AuthorsReadRight Then
				SearchForOptionsAndSubsystems = SearchForOptionsAndSubsystems
				+ Chars.LF
				+ "				Or "
				+ StrReplace(SearchTemplate, "<TableName.FieldName>", "ReportsOptions.AuthorPresentation");
			EndIf;
			SearchForOptionsAndSubsystems = SearchForOptionsAndSubsystems + ")";
			QueryText = StrReplace(QueryText, "&SearchForOptionsAndSubsystems", SearchForOptionsAndSubsystems);
			
			SearchForUserSettings = (
				"("
				+ StrReplace(SearchTemplate, "<TableName.FieldName>", "UserSettings.Description")
				+ ")");
			QueryText = StrReplace(QueryText, "&SearchForUserSettings", SearchForUserSettings);
			
		Else
			// Deleting a filter to search in option data and subsystem data.
			QueryText = StrReplace(QueryText, "AND &SearchForOptionsAndSubsystems", "");
			// Deleting a table to search in user settings.
			StartOfSelectionFromTable = (
				"UNION ALL
				|
				|SELECT DISTINCT
				|	UserSettings.Variant,");
			QueryText = TrimR(Left(QueryText, StrFind(QueryText, StartOfSelectionFromTable) - 1));
		EndIf;
		
		// Deleting excess fields when they are required neither for the search, nor for the resulting table.
		If Not HasSearchString AND Not GetSummaryTable Then
			// OptionDescription
			QueryText = StrReplace(QueryText, "ReportsOptions.Description AS", "UNDEFINED AS");
			// FieldDescriptions
			QueryText = StrReplace(
				QueryText,
				"CASE
				|		WHEN SUBSTRING(ReportsOptions.FieldDescriptions, 1, 1) = """"
				|			THEN CAST(ISNULL(ConfigurationOptions.FieldDescriptions, ExtensionOptions.FieldDescriptions) AS STRING(1000))
				|		ELSE CAST(ReportsOptions.FieldDescriptions AS STRING(1000))
				|	END AS",
				"UNDEFINED AS");
			// FilterParameterDescriptions
			QueryText = StrReplace(
				QueryText,
				"CASE
				|		WHEN SUBSTRING(ReportsOptions.FilterParameterDescriptions, 1, 1) = """"
				|			THEN CAST(ISNULL(ConfigurationOptions.FilterParameterDescriptions, ExtensionOptions.FilterParameterDescriptions) AS STRING(1000))
				|		ELSE CAST(ReportsOptions.FilterParameterDescriptions AS STRING(1000))
				|	END AS",
				"UNDEFINED AS");
			// Keywords
			QueryText = StrReplace(
				QueryText,
				"CASE
				|		WHEN SUBSTRING(ReportsOptions.Keywords, 1, 1) = """"
				|			THEN CAST(ISNULL(ConfigurationOptions.Keywords, ExtensionOptions.Keywords) AS STRING(1000))
				|		ELSE CAST(ReportsOptions.Keywords AS STRING(1000))
				|	END AS",
				"UNDEFINED AS");
			// Details
			QueryText = StrReplace(
				QueryText,
				"CASE
				|		WHEN SUBSTRING(ReportsOptions.Details, 1, 1) = """"
				|			THEN CAST(ISNULL(ConfigurationOptions.Details, ExtensionOptions.Details) AS STRING(1000))
				|		ELSE CAST(ReportsOptions.Details AS STRING(1000))
				|	END AS",
				"UNDEFINED AS");
			// SubsystemDescription
			QueryText = StrReplace(
				QueryText,
				"CASE
				|			WHEN OptionsPlacement.Subsystem.FullName = ""Subsystems""
				|				THEN &DesktopDescription
				|			ELSE OptionsPlacement.Subsystem.Synonym
				|		END AS",
				"UNDEFINED");
			QueryText = StrReplace(
				QueryText,
				"CASE
				|				WHEN ConfigurationPlacement.Subsystem.FullName = ""Subsystems""
				|					THEN &DesktopDescription
				|				ELSE ConfigurationPlacement.Subsystem.Synonym
				|			END",
				"UNDEFINED");
			QueryText = StrReplace(
				QueryText,
				"CASE
				|				WHEN ExtensionsPlacement.Subsystem.FullName = ""Subsystems""
				|					THEN &DesktopDescription
				|				ELSE ExtensionsPlacement.Subsystem.Synonym
				|			END",
				"UNDEFINED");
		Else
			Query.SetParameter("DesktopDescription", NStr("ru = 'Начальная страница'; en = 'Home page'; pl = 'Strona początkowa';es_ES = 'Página principal';es_CO = 'Página principal';tr = 'Ana sayfa';it = 'Pagina iniziale';de = 'Startseite'"));
		EndIf;
		
		// Deleting excess fields when they are not required for the resulting table.
		If Not GetSummaryTable Then
			QueryText = StrReplace(QueryText, "ReportsOptions.Author AS", "UNDEFINED AS");
			QueryText = StrReplace(QueryText, "ReportsOptions.Report AS", "UNDEFINED AS");
			QueryText = StrReplace(QueryText, "ReportsOptions.Report.Name AS", "UNDEFINED AS");
			QueryText = StrReplace(QueryText, "ReportsOptions.VariantKey AS", "UNDEFINED AS");
			QueryText = StrReplace(QueryText, "ReportsOptions.ReportType AS", "UNDEFINED AS");
		EndIf;
		
	Else
		
		QueryText =
		"SELECT ALLOWED
		|	ReportsOptions.Ref AS Ref,
		|	ReportsOptions.VariantKey AS VariantKey,
		|	ReportsOptions.Parent AS Parent,
		|	ReportsOptions.Description AS Description,
		|	ReportsOptions.Details AS Details,
		|	ReportsOptions.AvailableToAuthorOnly AS AvailableToAuthorOnly,
		|	ReportsOptions.Author AS Author
		|FROM
		|	Catalog.ReportsOptions AS ReportsOptions
		|WHERE
		|	ReportsOptions.ReportType IN(&ReportTypes)
		|	AND ReportsOptions.Report IN(&UserReports)
		|	AND NOT ReportsOptions.PredefinedVariant IN (&DIsabledApplicationOptions)
		|	AND (NOT ReportsOptions.Custom
		|			OR NOT ReportsOptions.InteractiveSetDeletionMark)
		|	AND (ReportsOptions.Custom
		|			OR NOT ReportsOptions.DeletionMark)
		|	AND &ShowPersonalReportsOptionsByOtherAuthors";
		
		If HasFilterByReportTypes Then
			Query.SetParameter("ReportTypes", SearchParameters.ReportTypes);
		Else
			QueryText = StrReplace(
				QueryText,
				"ReportsOptions.ReportType IN(&ReportTypes)
				|	AND ",
				"");
		EndIf;
		
	EndIf;
	
	QueryText = StrReplace(QueryText, "&ShowPersonalReportsOptionsByOtherAuthors", 
		?(Users.IsFullUser(), "True", "(ReportsOptions.AvailableToAuthorOnly = FALSE
			|	OR ReportsOptions.Author = &CurrentUser)"));
	Query.Text = QueryText;
	
	Result = New Structure;
	Result.Insert("References", New Array);
	Result.Insert("OptionsHighlight", New Map);
	Result.Insert("Subsystems", New Array);
	Result.Insert("SubsystemsHighlight", New Map);
	Result.Insert("OptionsLinkedWithSubsystems", New Map);
	Result.Insert("ParentsLinkedWithOptions", New Array);
	
	ValueTable = Query.Execute().Unload();
	If GetSummaryTable Then
		Result.Insert("ValueTable", ValueTable);
	EndIf;
	
	If ValueTable.Count() = 0 Then
		Return Result;
	EndIf;
	
	If Not HasSearchString Then
		ReportOptionsTable = ValueTable.Copy(, "Ref, Parent");
		ReportOptionsTable.GroupBy("Ref, Parent");
		For Each TableRow In ReportOptionsTable Do
			If ValueIsFilled(TableRow.Ref) AND Result.References.Find(TableRow.Ref) = Undefined Then
				Result.References.Add(TableRow.Ref);
				If ValueIsFilled(TableRow.Parent) AND Result.References.Find(TableRow.Parent) = Undefined Then
					Result.References.Add(TableRow.Parent);
				EndIf;
			EndIf;
		EndDo;
		Return Result;
	EndIf;
	
	ValueTable.Sort("Ref");
	
	SearchAreaTemplate = New FixedStructure("Value, FoundWordsCount, WordHighlighting", "", 0, New ValueList);
	
	TableRow = ValueTable[0];
	Option = New Structure;
	Option.Insert("Ref", TableRow.Ref);
	Option.Insert("Parent", TableRow.Parent);
	Option.Insert("OptionDescription",                 New Structure(SearchAreaTemplate));
	Option.Insert("Details",                             New Structure(SearchAreaTemplate));
	Option.Insert("FieldDescriptions",                    New Structure(SearchAreaTemplate));
	Option.Insert("FilterParameterDescriptions",       New Structure(SearchAreaTemplate));
	Option.Insert("Keywords",                        New Structure(SearchAreaTemplate));
	Option.Insert("UserSettingsDescriptions", New Structure(SearchAreaTemplate));
	Option.Insert("SubsystemsDescriptions",                New Structure(SearchAreaTemplate));
	Option.Insert("Subsystems",                           New Array);
	Option.Insert("AuthorPresentation",                  New Structure(SearchAreaTemplate));
	
	PresentationSeparator = ReportsOptionsClientServer.PresentationSeparator();
	
	Count = ValueTable.Count();
	For Index = 1 To Count Do
		// Filling in variables.
		If Not ValueIsFilled(Option.OptionDescription.Value) AND ValueIsFilled(TableRow.OptionDescription) Then
			Option.OptionDescription.Value = TableRow.OptionDescription;
		EndIf;
		If Not ValueIsFilled(Option.Details.Value) AND ValueIsFilled(TableRow.Details) Then
			Option.Details.Value = TableRow.Details;
		EndIf;
		If Not ValueIsFilled(Option.FieldDescriptions.Value) AND ValueIsFilled(TableRow.FieldDescriptions) Then
			Option.FieldDescriptions.Value = TableRow.FieldDescriptions;
		EndIf;
		If Not ValueIsFilled(Option.FilterParameterDescriptions.Value) AND ValueIsFilled(TableRow.FilterParameterDescriptions) Then
			Option.FilterParameterDescriptions.Value = TableRow.FilterParameterDescriptions;
		EndIf;
		If Not ValueIsFilled(Option.Keywords.Value) AND ValueIsFilled(TableRow.Keywords) Then
			Option.Keywords.Value = TableRow.Keywords;
		EndIf;
		If Not ValueIsFilled(Option.AuthorPresentation.Value) AND ValueIsFilled(TableRow.AuthorPresentation) Then
			Option.AuthorPresentation.Value = TableRow.AuthorPresentation;
		EndIf;
		If ValueIsFilled(TableRow.UserSettingPresentation) Then
			If Option.UserSettingsDescriptions.Value = "" Then
				Option.UserSettingsDescriptions.Value = TableRow.UserSettingPresentation;
			Else
				Option.UserSettingsDescriptions.Value = Option.UserSettingsDescriptions.Value
					+ PresentationSeparator
					+ TableRow.UserSettingPresentation;
			EndIf;
		EndIf;
		If ValueIsFilled(TableRow.SubsystemDescription)
			AND Option.Subsystems.Find(TableRow.Subsystem) = Undefined Then
			Option.Subsystems.Add(TableRow.Subsystem);
			Subsystem = Result.SubsystemsHighlight.Get(TableRow.Subsystem);
			If Subsystem = Undefined Then
				Subsystem = New Structure;
				Subsystem.Insert("Ref", TableRow.Subsystem);
				Subsystem.Insert("SubsystemDescription", New Structure(SearchAreaTemplate));
				Subsystem.SubsystemDescription.Value = TableRow.SubsystemDescription;
				Subsystem.Insert("AllWordsFound", True);
				Subsystem.Insert("FoundWords", New Array);
				For Each Word In WordArray Do
					If MarkWord(Subsystem.SubsystemDescription, Word) Then
						Subsystem.FoundWords.Add(Word);
					Else
						Subsystem.AllWordsFound = False;
					EndIf;
				EndDo;
				If Subsystem.AllWordsFound Then
					Result.Subsystems.Add(Subsystem.Ref);
				EndIf;
				Result.SubsystemsHighlight.Insert(Subsystem.Ref, Subsystem);
			EndIf;
			If Option.SubsystemsDescriptions.Value = "" Then
				Option.SubsystemsDescriptions.Value = TableRow.SubsystemDescription;
			Else
				Option.SubsystemsDescriptions.Value = Option.SubsystemsDescriptions.Value
					+ PresentationSeparator
					+ TableRow.SubsystemDescription;
			EndIf;
		EndIf;
		
		If Index < Count Then
			TableRow = ValueTable[Index];
		EndIf;
		
		If Index = Count Or TableRow.Ref <> Option.Ref Then
			// Analyzing collected information about the option.
			AllWordsFound = True;
			LinkedSubsystems = New Array;
			For Each Word In WordArray Do
				WordFound = False;
				
				If MarkWord(Option.OptionDescription, Word) Then
					WordFound = True;
				EndIf;
				
				If MarkWord(Option.Details, Word) Then
					WordFound = True;
				EndIf;
				
				If MarkWord(Option.FieldDescriptions, Word, True) Then
					WordFound = True;
				EndIf;
				
				If MarkWord(Option.AuthorPresentation, Word, True) Then
					WordFound = True;
				EndIf;
				
				If MarkWord(Option.FilterParameterDescriptions, Word, True) Then
					WordFound = True;
				EndIf;
				
				If MarkWord(Option.Keywords, Word, True) Then
					WordFound = True;
				EndIf;
				
				If MarkWord(Option.UserSettingsDescriptions, Word, True) Then
					WordFound = True;
				EndIf;
				
				If Not WordFound Then
					For Each SubsystemRef In Option.Subsystems Do
						Subsystem = Result.SubsystemsHighlight.Get(SubsystemRef);
						If Subsystem.FoundWords.Find(Word) <> Undefined Then
							WordFound = True;
							LinkedSubsystems.Add(SubsystemRef);
						EndIf;
					EndDo;
				EndIf;
				
				If Not WordFound Then
					AllWordsFound = False;
					Break;
				EndIf;
			EndDo;
			
			If AllWordsFound Then // Register the result.
				Result.References.Add(Option.Ref);
				Result.OptionsHighlight.Insert(Option.Ref, Option);
				If LinkedSubsystems.Count() > 0 Then
					Result.OptionsLinkedWithSubsystems.Insert(Option.Ref, LinkedSubsystems);
				EndIf;
				// Deleting the "from subordinate" connection if a parent is found independently.
				ParentIndex = Result.ParentsLinkedWithOptions.Find(Option.Ref);
				If ParentIndex <> Undefined Then
					Result.ParentsLinkedWithOptions.Delete(ParentIndex);
				EndIf;
				If ValueIsFilled(Option.Parent) AND Result.References.Find(Option.Parent) = Undefined Then
					Result.References.Add(Option.Parent);
					Result.ParentsLinkedWithOptions.Add(Option.Parent);
				EndIf;
			EndIf;
			
			If Index = Count Then
				Break;
			EndIf;
			
			// Zeroing variables.
			Option = New Structure;
			Option.Insert("Ref", TableRow.Ref);
			Option.Insert("Parent", TableRow.Parent);
			Option.Insert("OptionDescription",                 New Structure(SearchAreaTemplate));
			Option.Insert("Details",                             New Structure(SearchAreaTemplate));
			Option.Insert("FieldDescriptions",                    New Structure(SearchAreaTemplate));
			Option.Insert("FilterParameterDescriptions",       New Structure(SearchAreaTemplate));
			Option.Insert("Keywords",                        New Structure(SearchAreaTemplate));
			Option.Insert("UserSettingsDescriptions", New Structure(SearchAreaTemplate));
			Option.Insert("SubsystemsDescriptions",                New Structure(SearchAreaTemplate));
			Option.Insert("Subsystems",                           New Array);
			Option.Insert("AuthorPresentation",                  New Structure(SearchAreaTemplate));
		EndIf;
		
	EndDo;
	
	Return Result;
EndFunction

Function DisabledReportOptions(Val UserReports = Undefined) Export
	
	If UserReports = Undefined Then
		UserReports = New Array(ReportsOptionsCached.AvailableReports());
	EndIf;
	
	// Get options that are unavailable by functional options.
	
	OptionsTable = ReportsOptionsCached.Parameters().FunctionalOptionsTable;
	ReportOptionsTable = OptionsTable.CopyColumns("PredefinedVariant, FunctionalOptionName");
	ReportOptionsTable.Columns.Add("OptionValue", New TypeDescription("Number"));
	
	For Each ReportRef In UserReports Do
		FoundItems = OptionsTable.FindRows(New Structure("Report", ReportRef));
		For Each TableRow In FoundItems Do
			RowOption = ReportOptionsTable.Add();
			FillPropertyValues(RowOption, TableRow);
			Value = GetFunctionalOption(TableRow.FunctionalOptionName);
			If Value = True Then
				RowOption.OptionValue = 1;
			EndIf;
		EndDo;
	EndDo;
	
	ReportOptionsTable.GroupBy("PredefinedVariant", "OptionValue");
	DisabledItemsTable = ReportOptionsTable.Copy(New Structure("OptionValue", 0));
	DisabledItemsTable.GroupBy("PredefinedVariant");
	DisabledOptions = DisabledItemsTable.UnloadColumn("PredefinedVariant");
	
	// Add options disabled by the developer.
	Query = New Query;
	Query.SetParameter("UserReports", UserReports);
	Query.SetParameter("ExtensionsVersion", SessionParameters.ExtensionsVersion);
	Query.SetParameter("DisabledOptionsArray", DisabledOptions);
	
	Query.Text =
	"SELECT ALLOWED
	|	ConfigurationOptions.Ref
	|FROM
	|	Catalog.PredefinedReportsOptions AS ConfigurationOptions
	|WHERE
	|	(ConfigurationOptions.Enabled = FALSE
	|		OR ConfigurationOptions.DeletionMark = TRUE)
	|	AND ConfigurationOptions.Report IN(&UserReports)
	|	AND NOT ConfigurationOptions.Ref IN (&DisabledOptionsArray)
	|
	|UNION ALL
	|
	|SELECT
	|	ExtensionOptions.Ref
	|FROM
	|	Catalog.PredefinedExtensionsReportsOptions AS ExtensionOptions
	|		LEFT JOIN InformationRegister.PredefinedExtensionsVersionsReportsOptions AS Versions
	|		ON ExtensionOptions.Ref = Versions.Variant
	|			AND ExtensionOptions.Report = Versions.Report
	|			AND (Versions.ExtensionsVersion = &ExtensionsVersion)
	|WHERE
	|	(ExtensionOptions.Enabled = FALSE
	|		OR Versions.Variant IS NULL)
	|	AND ExtensionOptions.Report IN(&UserReports)
	|	AND NOT ExtensionOptions.Ref IN (&DisabledOptionsArray)";
	
	ItemsDisabledByDeveloper = Query.Execute().Unload().UnloadColumn(0);
	CommonClientServer.SupplementArray(DisabledOptions, ItemsDisabledByDeveloper);
	
	Return DisabledOptions;
	
EndFunction

// Finds a word and marks a place where it was found. Returns True if the word is found.
Function MarkWord(StructureWhere, Word, UseSeparator = False) Export
	If StrStartsWith(StructureWhere.Value, "#") Then
		StructureWhere.Value = Mid(StructureWhere.Value, 2);
	EndIf;
	RemainderInReg = Upper(StructureWhere.Value);
	Position = StrFind(RemainderInReg, Word);
	If Position = 0 Then
		Return False;
	EndIf;
	If StructureWhere.FoundWordsCount = 0 Then
		// Initializing a variable that contains directives for highlighting words.
		StructureWhere.WordHighlighting = New ValueList;
		// Scrolling focus to a meaningful word (of the found information).
		If UseSeparator Then
			StorageSeparator = ReportsOptionsClientServer.StorageSeparator();
			PresentationSeparator = ReportsOptionsClientServer.PresentationSeparator();
			SeparatorLength = StrLen(StorageSeparator);
			While Position > 10 Do
				SeparatorPosition = StrFind(RemainderInReg, StorageSeparator);
				If SeparatorPosition = 0 Then
					Break;
				EndIf;
				If SeparatorPosition < Position Then
					// Moving a fragment to the separator at the end of area.
					StructureWhere.Value = (
						Mid(StructureWhere.Value, SeparatorPosition + SeparatorLength)
						+ StorageSeparator
						+ Left(StructureWhere.Value, SeparatorPosition - 1));
					RemainderInReg = (
						Mid(RemainderInReg, SeparatorPosition + SeparatorLength)
						+ StorageSeparator
						+ Left(RemainderInReg, SeparatorPosition - 1));
					// Updating information on word location.
					Position = Position - SeparatorPosition - SeparatorLength + 1;
				Else
					Break;
				EndIf;
			EndDo;
			StructureWhere.Value = StrReplace(StructureWhere.Value, StorageSeparator, PresentationSeparator);
			RemainderInReg = StrReplace(RemainderInReg, StorageSeparator, PresentationSeparator);
			Position = StrFind(RemainderInReg, Word);
		EndIf;
	EndIf;
	// Registering a found word.
	StructureWhere.FoundWordsCount = StructureWhere.FoundWordsCount + 1;
	// Marking words.
	LeftPartLength = 0;
	WordLength = StrLen(Word);
	While Position > 0 Do
		StructureWhere.WordHighlighting.Add(LeftPartLength + Position, "+");
		StructureWhere.WordHighlighting.Add(LeftPartLength + Position + WordLength, "-");
		RemainderInReg = Mid(RemainderInReg, Position + WordLength);
		LeftPartLength = LeftPartLength + Position + WordLength - 1;
		Position = StrFind(RemainderInReg, Word);
	EndDo;
	Return True;
EndFunction

// Deletes a temporary table from the query text.
Procedure DeleteTemporaryTable(QueryText, TemporaryTableName)
	TemporaryTablePosition = StrFind(QueryText, "INTO " + TemporaryTableName);
	LeftPart = "";
	RightPart = QueryText;
	While True Do
		SemicolonPosition = StrFind(RightPart, Chars.LF + ";");
		If SemicolonPosition = 0 Then
			Break;
		ElsIf SemicolonPosition > TemporaryTablePosition Then
			RightPart = Mid(RightPart, SemicolonPosition + 2);
			Break;
		Else
			LeftPart = LeftPart + Left(RightPart, SemicolonPosition + 1);
			RightPart = Mid(RightPart, SemicolonPosition + 2);
			TemporaryTablePosition = TemporaryTablePosition - SemicolonPosition - 1;
		EndIf;
	EndDo;
	QueryText = LeftPart + RightPart;
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Defining tabled to be used.

// Registers tables used in data sets in the array.
Procedure RegisterDataSetsTables(Tables, DataSets)
	For Each Set In DataSets Do
		If TypeOf(Set) = Type("DataCompositionSchemaDataSetQuery") Then
			RegisterQueryTables(Tables, Set.Query);
		ElsIf TypeOf(Set) = Type("DataCompositionSchemaDataSetUnion") Then
			RegisterDataSetsTables(Tables, Set.Items);
		ElsIf TypeOf(Set) = Type("DataCompositionSchemaDataSetObject") Then
			// Nothing to register.
		EndIf;
	EndDo;
EndProcedure

// Registers tables used in the query in the array.
Procedure RegisterQueryTables(Tables, QueryText)
	If Not ValueIsFilled(QueryText) Then
		Return;
	EndIf;
	QuerySchema = New QuerySchema;
	QuerySchema.SetQueryText(QueryText);
	For Each Query In QuerySchema.QueryBatch Do
		If TypeOf(Query) = Type("QuerySchemaSelectQuery") Then
			RegisterQueryOperatorsTables(Tables, Query.Operators);
		ElsIf TypeOf(Query) = Type("QuerySchemaTableDropQuery") Then
			// Nothing to register.
		EndIf;
	EndDo;
EndProcedure

// Continuation of the procedure (see above).
Procedure RegisterQueryOperatorsTables(Tables, Operators)
	For Each Operator In Operators Do
		For Each Source In Operator.Sources Do
			Source = Source.Source;
			If TypeOf(Source) = Type("QuerySchemaTable") Then
				If Tables.Find(Source.TableName) = Undefined Then
					Tables.Add(Source.TableName);
				EndIf;
			ElsIf TypeOf(Source) = Type("QuerySchemaNestedQuery") Then
				RegisterQueryOperatorsTables(Tables, Source.Query.Operators);
			ElsIf TypeOf(Source) = Type("QuerySchemaTempTableDescription") Then
				// Nothing to register.
			EndIf;
		EndDo;
	EndDo;
EndProcedure

// Returns a message text that the report data is still being updated.
Function DataIsBeingUpdatedMessage() Export
	Return NStr("ru = 'Отчет может содержать некорректные данные, так как не завершен переход на новую версию программы. Если отчет долгое время недоступен, необходимо обратиться к администратору.'; en = 'The report can contain incorrect data as transition to a new application version is not completed. If the report is not available for a long time, contact the administrator.'; pl = 'Raport może zawierać niepoprawne dane, ponieważ nie zakończono przejścia na nową wersję programu. Jeżeli raport jest niedostępny przez długi czas, należy zwrócić się do administratora.';es_ES = 'El informe puede contener datos incorrectos porque no está terminado el paso a la nueva versión del programa. Si el informe no está disponible durante mucho tiempo, es necesario dirigirse al administrador.';es_CO = 'El informe puede contener datos incorrectos porque no está terminado el paso a la nueva versión del programa. Si el informe no está disponible durante mucho tiempo, es necesario dirigirse al administrador.';tr = 'Rapor, programın yeni sürümüne geçiş tamamlanmadığı için hatalı veriler içerebilir. Rapor uzun süre kullanılamıyorsa, yöneticinize başvurun.';it = 'Il report potrebbe contenere dati non corretti poiché il passaggio alla nuova versione del programma non è completato. Se il report non è disponibile per un tempo prolungato, contattare l''amministratore.';de = 'Der Bericht kann falsche Daten enthalten, da die Umstellung auf die neue Version des Programms nicht abgeschlossen ist. Wenn der Bericht längere Zeit nicht verfügbar ist, sollten Sie sich an den Administrator wenden.'");
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Reports submenu.

// Called from OnDefineCommandsAttachedToObject.
Procedure OnAddReportsCommands(Commands, ObjectInfo, FormSettings)
	ObjectInfo.Manager.AddReportCommands(Commands, FormSettings);
	AddedCommands = Commands.FindRows(New Structure("Processed", False));
	For Each Command In AddedCommands Do
		If Not ValueIsFilled(Command.Manager) Then
			Command.Manager = ObjectInfo.FullName;
		EndIf;
		If Not ValueIsFilled(Command.ParameterType) Then
			If TypeOf(ObjectInfo.DataRefType) = Type("Type") Then
				Command.ParameterType = New TypeDescription(CommonClientServer.ValueInArray(ObjectInfo.DataRefType));
			Else // Type("TypesDetails") or Undefined.
				Command.ParameterType = ObjectInfo.DataRefType;
			EndIf;
		EndIf;
		Command.Processed = True;
	EndDo;
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Other.

// Adds an element to the array with uniqueness control.
Procedure AddToArray(Array, Value)
	If Array.Find(Value) = Undefined Then
		Array.Add(Value);
	EndIf;
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Auxiliary for the internal

// Handler determining whether configuration reports and extensions are available.
Procedure OnDetermineReportsAvailability(ReportsReferences, Result)
	ReportsNames = Common.ObjectsAttributeValue(ReportsReferences, "Name", True);
	For Each Report In ReportsReferences Do
		NameOfReport = ReportsNames[Report];
		AvailableByRLS = True;
		AvailableByRights = True;
		AvailableByOptions = True;
		FoundInApplication = True;
		If NameOfReport = Undefined Then
			AvailableByRLS = False;
		Else
			ReportMetadata = Metadata.Reports.Find(NameOfReport);
			If ReportMetadata = Undefined Then
				FoundInApplication = False;
			ElsIf Not AccessRight("View", ReportMetadata) Then
				AvailableByRights = False;
			ElsIf Not Common.MetadataObjectAvailableByFunctionalOptions(ReportMetadata) Then
				AvailableByOptions = False;
			EndIf;
		EndIf;
		FoundItems = Result.FindRows(New Structure("Report", Report));
		For Each TableRow In FoundItems Do
			If Not AvailableByRLS Then
				TableRow.Presentation = NStr("ru = '<Недостаточно прав для работы с вариантом отчета>'; en = '<Insufficient rights to access the report option>'; pl = '<Niewystarczające uprawnienia do pracy z wariantem raportu>';es_ES = '<Insuficientes derechos para usar la variante del informe>';es_CO = '<Insuficientes derechos para usar la variante del informe>';tr = '<Rapor seçeneği ile çalışma hakları yetersiz>';it = '<Permessi insufficienti per accedere alla variante di report>';de = '<Unzureichende Rechte, um mit der Berichtsvariante zu arbeiten>'");
			ElsIf Not FoundInApplication Then
				TableRow.Presentation = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = '<Отчет ""%1"" не найден в программе>'; en = '<The ""%1"" report is not found in the application>'; pl = '<Nie znaleziono raportu ""%1"" w programie>';es_ES = '<Informe ""%1"" no encontrado en el programa>';es_CO = '<Informe ""%1"" no encontrado en el programa>';tr = '<""%1"" raporu uygulamada bulunamadı>';it = '<Il report ""%1"" non è stato trovato nella applicazione>';de = '<Bericht ""%1"" nicht im Programm gefunden>'"),
					NameOfReport);
			ElsIf Not AvailableByRights Then
				TableRow.Presentation = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = '<Недостаточно прав для работы с отчетом ""%1"">'; en = '<Insufficient rights to access the report ""%1"">'; pl = '<Niewystarczające uprawnienia do pracy z raportem ""%1"">';es_ES = '<Insuficientes derechos para usar la variante del informe ""%1"">';es_CO = '<Insuficientes derechos para usar la variante del informe ""%1"">';tr = '<""%1"" rapor seçeneği ile çalışma hakları yetersiz>';it = '<Permessi non sufficienti per accedere al report ""%1"">';de = '<Unzureichende Rechte, um mit dem Bericht ""%1"" zu arbeiten>'"),
					NameOfReport);
			ElsIf Not AvailableByOptions Then
				TableRow.Presentation = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = '<Отчет ""%1"" отключен в настройках программы>'; en = '<The ""%1"" report is disabled in the application settings>'; pl = '<Raport ""%1"" jest odłączony w ustawieniach programu>';es_ES = '<El informe ""%1"" está declinado en los ajustes del programa>';es_CO = '<El informe ""%1"" está declinado en los ajustes del programa>';tr = '<""%1"" rapor uygulama ayarlarında kapalı>';it = '<Il report""%1"" è disabilitato nelle impostazioni dell''applicazione>';de = '<Bericht ""%1"" ist in den Programmeinstellungen deaktiviert>'"),
					NameOfReport);
			Else
				TableRow.Available = True;
			EndIf;
		EndDo;
	EndDo;
EndProcedure

// Determines the attachment method of the common report form.
Function ByDefaultAllConnectedToMainForm()
	MetadataForm = Metadata.DefaultReportForm;
	Return (MetadataForm <> Undefined AND MetadataForm = Metadata.CommonForms.ReportForm);
EndFunction

// Defines an attachement method of the common report settings form.
Function ByDefaultAllConnectedToSettingsForm()
	MetadataForm = Metadata.DefaultReportSettingsForm;
	Return (MetadataForm <> Undefined AND MetadataForm = Metadata.CommonForms.ReportSettingsForm);
EndFunction

// Defines an attachment method of the report option storage.
Function ByDefaultAllConnectedToStorage()
	Return (Metadata.ReportsVariantsStorage <> Undefined AND Metadata.ReportsVariantsStorage.Name = "ReportsVariantsStorage");
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Filters.

// Sets filters based on extended information from the structure.
Procedure ComplementFiltersFromStructure(Filter, Structure, DisplayMode = Undefined) Export
	If DisplayMode = Undefined Then
		DisplayMode = DataCompositionSettingsItemViewMode.Inaccessible;
	EndIf;
	For Each KeyAndValue In Structure Do
		FieldName = KeyAndValue.Key;
		FieldFilter = KeyAndValue.Value;
		Type = TypeOf(FieldFilter);
		If Type = Type("Structure") Then
			Condition = DataCompositionComparisonType[FieldFilter.Kind];
			Value = FieldFilter.Value;
		ElsIf Type = Type("Array") Then
			Condition = DataCompositionComparisonType.InList;
			Value = FieldFilter;
		ElsIf Type = Type("ValueList") Then
			Condition = DataCompositionComparisonType.InList;
			Value = FieldFilter.UnloadValues();
		ElsIf Type = Type("DataCompositionComparisonType") Then
			Condition = FieldFilter;
			Value = Undefined;
		Else
			Condition = DataCompositionComparisonType.Equal;
			Value = FieldFilter;
		EndIf;
		CommonClientServer.SetFilterItem(
			Filter,
			FieldName,
			Value,
			Condition,
			,
			True,
			DisplayMode);
	EndDo;
EndProcedure

Function CheckEmptyFilters(FilterItems)
	
	Result = New Structure;
	
	For Each FilterItem In FilterItems Do
		
		If FilterItem.Use And TypeOf(FilterItem) = Type("DataCompositionFilterItem") And Not ValueIsFilled(FilterItem.LeftValue) Then
			
			Result.Insert("Success", False);
			Result.Insert("ErrorText", NStr("en = 'Filter''s data is empty. Please fill filters properly and try again.'; ru = 'Данные отбора пусты. Заполните отборы и повторите попытку.';pl = 'Dane filtru są puste. Prawidłowo wypełnij filtry i spróbuj ponownie.';es_ES = 'Los datos del filtro están vacíos. Por favor, rellena los filtros correctamente e inténtalo de nuevo.';es_CO = 'Los datos del filtro están vacíos. Por favor, rellena los filtros correctamente e inténtalo de nuevo.';tr = 'Filtre verileri boş. Lütfen, filtreleri doğru şekilde doldurup tekrar deneyin.';it = 'I dati del filtro sono vuoti. Compilare adeguatamente il filtro e riprovare.';de = 'Daten des Filters sind leer. Füllen Sie bitte Filter ordnungsgemäß auf und versuchen Sie erneut.'"));
			Return Result;
			
		ElsIf FilterItem.Use And TypeOf(FilterItem) = Type("DataCompositionFilterItemGroup") Then
			
			Result = CheckEmptyFilters(FilterItem.Items);
			If Result.Property("Success") Then
				Return Result;
			EndIf;
			
		EndIf;
		
	EndDo;
	
	Return Result;
	
EndFunction

#EndRegion
