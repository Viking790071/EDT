#Region Public

// Opens a form of the specified report.
//
// Parameters:
//   OwnerForm - ClientApplicationForm, Undefined - a form that opens the report.
//   Option - CatalogRef.ReportsOptions, CatalogRef.AdditionalReportsAndDataProcessors - a report 
//       option to open the form for. If the CatalogRef.AdditionalReportsAndDataProcessors type is 
//       passed, an additional report attached to the application is opened.
//   AdditionalParameters - Structure - an internal parameter that is not intended for use.
//
Procedure OpenReportForm(Val OwnerForm, Val Option, Val AdditionalParameters = Undefined) Export
	Type = TypeOf(Option);
	If Type = Type("Structure") Then
		OpeningParameters = Option;
	ElsIf Type = Type("CatalogRef.ReportsOptions") 
		Or Type = ReportsOptionsClientServer.AdditionalReportRefType() Then
		OpeningParameters = New Structure("Key", Option);
		If AdditionalParameters <> Undefined Then
			CommonClientServer.SupplementStructure(OpeningParameters, AdditionalParameters, True);
		EndIf;
		OpenForm("Catalog.ReportsOptions.ObjectForm", OpeningParameters, Undefined, True);
		Return;
	Else
		OpeningParameters = New Structure("Ref, Report, ReportType, ReportName, VariantKey, MeasurementsKey");
		If TypeOf(OwnerForm) = Type("ClientApplicationForm") Then
			FillPropertyValues(OpeningParameters, OwnerForm);
		EndIf;
		FillPropertyValues(OpeningParameters, Option);
	EndIf;
	
	If AdditionalParameters <> Undefined Then
		CommonClientServer.SupplementStructure(OpeningParameters, AdditionalParameters, True);
	EndIf;
	
	ReportsOptionsClientServer.AddKeyToStructure(OpeningParameters, "RunMeasurements", False);
	
	OpeningParameters.ReportType = ReportsOptionsClientServer.ReportByStringType(OpeningParameters.ReportType, OpeningParameters.Report);
	If Not ValueIsFilled(OpeningParameters.ReportType) Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Не определен тип отчета в %1'; en = 'Report type is not specified in %1'; pl = 'Nie określono rodzaju sprawozdania w %1';es_ES = 'Tipo de informe en %1 no está determinado';es_CO = 'Tipo de informe en %1 no está determinado';tr = 'Rapor türü %1 belirlenmedi';it = 'Tipo del report non definito in %1';de = 'Der Berichtstyp in %1 ist nicht festgelegt'"), "ReportsOptionsClient.OpenReportForm");
	EndIf;
	
	If OpeningParameters.ReportType = "Internal" Or OpeningParameters.ReportType = "Extension" Then
		Kind = "Report";
		MeasurementsKey = CommonClientServer.StructureProperty(OpeningParameters, "MeasurementsKey");
		If ValueIsFilled(MeasurementsKey) Then
			ClientParameters = ClientParameters();
			If ClientParameters.RunMeasurements Then
				OpeningParameters.RunMeasurements = True;
				OpeningParameters.Insert("OperationName", MeasurementsKey + ".Opening");
				OpeningParameters.Insert("OperationComment", ClientParameters.MeasurementsPrefix);
			EndIf;
		EndIf;
	ElsIf OpeningParameters.ReportType = "Additional" Then
		Kind = "ExternalReport";
		If Not OpeningParameters.Property("Connected") Then
			ReportsOptionsServerCall.OnAttachReport(OpeningParameters);
		EndIf;
		If Not OpeningParameters.Connected Then
			Return;
		EndIf;
	Else
		ShowMessageBox(, NStr("ru = 'Вариант внешнего отчета можно открыть только из формы отчета.'; en = 'External report option can be opened only from the report form.'; pl = 'Opcja sprawozdania zewnętrznego może zostać otwarta tylko z formularza sprawozdania.';es_ES = 'Opción de un informe externo puede abrirse solo desde el formulario de informes.';es_CO = 'Opción de un informe externo puede abrirse solo desde el formulario de informes.';tr = 'Harici rapor seçeneği sadece rapor formundan açılabilir.';it = 'Una variante di report esterna può essere aperta solo dal  modulo report.';de = 'Die Option für den externen Bericht kann nur über das Berichtsformular geöffnet werden.'"));
		Return;
	EndIf;
	
	If Not ValueIsFilled(OpeningParameters.ReportName) Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Не определено имя отчета в %1'; en = 'Report name is not specified in %1'; pl = 'Nie określono nazwy sprawozdania w %1';es_ES = 'Nombre del informe no está determinado en %1';es_CO = 'Nombre del informe no está determinado en %1';tr = 'Rapor adı %1''de belirlenmedi';it = 'Nome del report non definito in %1';de = 'Der Berichtsname ist nicht in festgelegt %1'"), "ReportsOptionsClient.OpenReportForm");
	EndIf;
	
	ReportFullName = Kind + "." + OpeningParameters.ReportName;
	
	UniqueKey = ReportsClientServer.UniqueKey(ReportFullName, OpeningParameters.VariantKey);
	OpeningParameters.Insert("PrintParametersKey",        UniqueKey);
	OpeningParameters.Insert("WindowOptionsKey", UniqueKey);
	
	If OpeningParameters.RunMeasurements Then
		ReportsOptionsClientServer.AddKeyToStructure(OpeningParameters, "OperationComment");
		ModulePerformanceMonitorClient = CommonClient.CommonModule("PerformanceMonitorClient");
		MeasurementID = ModulePerformanceMonitorClient.StartTimeMeasurement(
			False,
			OpeningParameters.OperationName);
		ModulePerformanceMonitorClient.SetMeasurementComment(MeasurementID, OpeningParameters.OperationComment);
	EndIf;
	
	OpenForm(ReportFullName + ".Form", OpeningParameters, Undefined, True);
	
	If OpeningParameters.RunMeasurements Then
		ModulePerformanceMonitorClient.StopTimeMeasurement(MeasurementID);
	EndIf;
EndProcedure

// Opens the report panel. To use from common command modules.
//
// Parameters:
//   PathToSubsystem - String - a section name or a path to the subsystem for which the report panel is opened.
//       Conforms to the following format: "SectionName[.NestedSubsystemName1][.NestedSubsystemName2][...]".
//       Section must be described in ReportsOptionsOverridable.DefineSectionsWithReportsOptions.
//   CommandExecuteParameters - CommandExecuteParameters - parameters of the common command handler.
//
Procedure ShowReportBar(PathToSubsystem, CommandExecutionParameters) Export
	ParametersForm = New Structure("PathToSubsystem", PathToSubsystem);
	
	WindowForm = ?(CommandExecutionParameters = Undefined, Undefined, CommandExecutionParameters.Window);
	ReferenceForm = ?(CommandExecutionParameters = Undefined, Undefined, CommandExecutionParameters.URL);
	
	ClientParameters = ClientParameters();
	If ClientParameters.RunMeasurements Then
		ModulePerformanceMonitorClient = CommonClient.CommonModule("PerformanceMonitorClient");
		MeasurementID = ModulePerformanceMonitorClient.StartTimeMeasurement(
			False,
			"ReportPanel.Opening");
		ModulePerformanceMonitorClient.SetMeasurementComment(MeasurementID, ClientParameters.MeasurementsPrefix + "; " + PathToSubsystem);
	EndIf;
	
	OpenForm("CommonForm.ReportPanel", ParametersForm, , PathToSubsystem, WindowForm, ReferenceForm);
	
	If ClientParameters.RunMeasurements Then
		ModulePerformanceMonitorClient.StopTimeMeasurement(MeasurementID);
	EndIf;
EndProcedure

// Opens the several options placement setting dialog in sections.
//
// Parameters:
//   Options - Array - report options to move (CatalogRef.ReportsOptions).
//   Owner - ClientApplicationForm - to block the owner window.
//
Procedure OpenOptionArrangeInSectionsDialog(Options, Owner = Undefined) Export
	
	If TypeOf(Options) <> Type("Array") Or Options.Count() < 1 Then
		ShowMessageBox(, NStr("ru = 'Выберите варианты отчетов, которые необходимо разместить в разделах.'; en = 'Select report options to be placed in sections.'; pl = 'Wybierz warianty sprawozdania, które chcesz umieścić w sekcjach.';es_ES = 'Seleccionar las opciones del informe para colocarse en las secciones.';es_CO = 'Seleccionar las opciones del informe para colocarse en las secciones.';tr = 'Bölümlere yerleştirilecek rapor seçeneklerini seçin.';it = 'Selezionare varianti report da inserire nelle sezioni.';de = 'Wählen Sie Berichtsoptionen aus, die in Abschnitte eingefügt werden sollen.'"));
		Return;
	EndIf;
	
	OpeningParameters = New Structure("Variants", Options);
	OpenForm("Catalog.ReportsOptions.Form.PlacementInSections", OpeningParameters, Owner);
	
EndProcedure

// Opens the dialog box to reset the user settings of the selected report options.
//
// Parameters:
//   Options - Array - processed report options (CatalogRef.ReportsOptions).
//   Owner - ClientApplicationForm - to block the owner window.
//
Procedure OpenResetUserSettingsDialog(Options, Owner = Undefined) Export
	
	If TypeOf(Options) <> Type("Array") Or Options.Count() < 1 Then
		ShowMessageBox(, NStr("ru = 'Выберите варианты отчетов, для которых необходимо сбросить пользовательские настройки.'; en = 'Select report options for which it is required to reset the custom settings.'; pl = 'Wybierz warianty sprawozdania, dla których wymagane jest zresetowanie ustawień niestandardowych.';es_ES = 'Seleccionar las opciones del informe para las cuales se requiere restablecer las configuraciones personales.';es_CO = 'Seleccionar las opciones del informe para las cuales se requiere restablecer las configuraciones personales.';tr = 'Özel ayarları sıfırlamanız gereken rapor seçeneklerini seçin.';it = 'Selezionare le varianti di report per i quali è richiesto di reimpostare le impostazione personalizzate.';de = 'Wählen Sie Berichtsoptionen aus, für die die benutzerdefinierten Einstellungen zurückgesetzt werden müssen.'"));
		Return;
	EndIf;
	
	OpeningParameters = New Structure;
	OpeningParameters.Insert("Variants", Options);
	OpenForm("Catalog.ReportsOptions.Form.ResetUserSettings", OpeningParameters, Owner);
	
EndProcedure

// Opens the dialog box to reset the settings of placing the selected application report options.
//
// Parameters:
//   Options - Array - processed report options (CatalogRef.ReportsOptions).
//   Owner - ClientApplicationForm - to block the owner window.
//
Procedure OpenResetPlacementSettingsDialog(Options, Owner = Undefined) Export
	
	If TypeOf(Options) <> Type("Array") OR Options.Count() < 1 Then
		ShowMessageBox(, NStr("ru = 'Выберите варианты отчетов программы, для которых необходимо сбросить настройки размещения.'; en = 'Select the application report options which location settings are to be reset.'; pl = 'Wybierz warianty raportu aplikacji, których ustawienia lokalizacji mają zostać zresetowane.';es_ES = 'Seleccionar las opciones del informe de la aplicación las configuraciones de la ubicación de las cuales tienen que restablecerse.';es_CO = 'Seleccionar las opciones del informe de la aplicación las configuraciones de la ubicación de las cuales tienen que restablecerse.';tr = 'Hangi konum ayarlarının sıfırlanacağını, uygulama raporu seçeneklerini seçin.';it = 'Selezionare il report del programma per il quale le impostazioni di localizzazione devono essere reimpostate.';de = 'Wählen Sie die Anwendungsbericht-Optionen, deren Standorteinstellungen zurückgesetzt werden sollen.'"));
		Return;
	EndIf;
	
	OpeningParameters = New Structure;
	OpeningParameters.Insert("Variants", Options);
	OpenForm("Catalog.ReportsOptions.Form.ResetAssignmentToSections", OpeningParameters, Owner);
	
EndProcedure

// Notifies open report panels and lists of forms and items about changes.
//
// Parameters:
//   Parameter - Arbitrary - any needed data can be passed.
//   Source - Arbitrary - an event source. For example, another form can be passed.
//
Procedure UpdateOpenForms(Parameter = Undefined, Source = Undefined) Export
	
	Notify(ReportsOptionsClientServer.EventNameChangingOption(), Parameter, Source);
	
EndProcedure

#EndRegion

#Region Internal

// Opens a report option card with the settings that define its placement in the application interface.
//
// Parameters:
//   Option - CatalogRef.ReportsOptions - a report option reference.
//
Procedure ShowReportSettings(Option) Export
	FormParameters = New Structure;
	FormParameters.Insert("ShowCard", True);
	FormParameters.Insert("Key", Option);
	OpenForm("Catalog.ReportsOptions.ObjectForm", FormParameters);
EndProcedure

#EndRegion

#Region Private

// The procedure handles an event of the SubsystemsTree attribute in editing forms.
Procedure SubsystemsTreeUsingOnChange(Form, Item) Export
	TreeRow = Form.Items.SubsystemsTree.CurrentData;
	If TreeRow = Undefined Then
		Return;
	EndIf;
	
	// Skip the root row
	If TreeRow.Priority = "" Then
		TreeRow.Use = 0;
		Return;
	EndIf;
	
	If TreeRow.Use = 2 Then
		TreeRow.Use = 0;
	EndIf;
	
	TreeRow.Modified = True;
EndProcedure

// The procedure handles an event of the SubsystemsTree attribute in editing forms.
Procedure SubsystemsTreeImportanceOnChange(Form, Item) Export
	TreeRow = Form.Items.SubsystemsTree.CurrentData;
	If TreeRow = Undefined Then
		Return;
	EndIf;
	
	// Skip the root row
	If TreeRow.Priority = "" Then
		TreeRow.Importance = "";
		Return;
	EndIf;
	
	If TreeRow.Importance <> "" Then
		TreeRow.Use = 1;
	EndIf;
	
	TreeRow.Modified = True;
EndProcedure

// The analog of CommonClient.ShowMultilineTextEditingForm, working in one call.
//   It allows you to set your own header and works with table attributes unlike CommonClient.
//   ShowCommentEditingForm.
//
Procedure EditMultilineText(FormOrHandler, EditText, AttributeOwner, AttributeName, Val Header = "") Export
	
	If IsBlankString(Header) Then
		Header = NStr("ru = 'Комментарий'; en = 'Comment'; pl = 'Uwagi';es_ES = 'Comentario';es_CO = 'Comentario';tr = 'YORUM';it = 'Commento';de = 'Kommentar'");
	EndIf;
	
	SourceParameters = New Structure;
	SourceParameters.Insert("FormOrHandler", FormOrHandler);
	SourceParameters.Insert("AttributeOwner",  AttributeOwner);
	SourceParameters.Insert("AttributeName",       AttributeName);
	Handler = New NotifyDescription("EditMultilineTextCompletion", ThisObject, SourceParameters);
	
	ShowInputString(Handler, EditText, Header, , True);
	
EndProcedure

// EditMultilineText procedure execution result handler.
Procedure EditMultilineTextCompletion(Text, SourceParameters) Export
	
	If TypeOf(SourceParameters.FormOrHandler) = Type("ClientApplicationForm") Then
		Form      = SourceParameters.FormOrHandler;
		Handler = Undefined;
	Else
		Form      = Undefined;
		Handler = SourceParameters.FormOrHandler;
	EndIf;
	
	If Text <> Undefined Then
		
		If TypeOf(SourceParameters.AttributeOwner) = Type("FormDataTreeItem")
			Or TypeOf(SourceParameters.AttributeOwner) = Type("FormDataCollectionItem") Then
			FillPropertyValues(SourceParameters.AttributeOwner, New Structure(SourceParameters.AttributeName, Text));
		Else
			SourceParameters.AttributeOwner[SourceParameters.AttributeName] = Text;
		EndIf;
		
		If Form <> Undefined Then
			If Not Form.Modified Then
				Form.Modified = True;
			EndIf;
		EndIf;
		
	EndIf;
	
	If Handler <> Undefined Then
		ExecuteNotifyProcessing(Handler, Text);
	EndIf;
	
EndProcedure

Function ClientParameters()
	Return CommonClientServer.StructureProperty(
		StandardSubsystemsClient.ClientParametersOnStart(),
		"ReportsOptions");
EndFunction

#EndRegion
