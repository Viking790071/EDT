#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure OnComposeResult(ResultDocument, DetailsData, StandardProcessing) Export

	StandardProcessing = False;
	
	ReportSettings = SettingsComposer.GetSettings();
	ReportParameters = PrepareReportParameters(ReportSettings);
	
	DriveReports.SetReportAppearanceTemplate(ReportSettings);
	DriveReports.OutputReportTitle(ReportParameters, ResultDocument);
	
	TemplateComposer = New DataCompositionTemplateComposer;
	CompositionTemplate = TemplateComposer.Execute(DataCompositionSchema, ReportSettings, DetailsData);
	
	DataCompositionParameterValue = CompositionTemplate.ParameterValues.Find("EndOfPeriod");
	If DataCompositionParameterValue = Undefined Then
		NewParameterValue = CompositionTemplate.ParameterValues.Add();
		NewParameterValue.Name = "EndOfPeriod";
		NewParameterValue.Value = Date(3999,12,31,23,59,59);
	EndIf;
	
	VATInputParameter = CompositionTemplate.ParameterValues.Find("VATInputText");
	VATInputParameter.Value = NStr("en = 'VAT input'; ru = 'Входящий НДС';pl = 'VAT naliczony';es_ES = 'Entrada del IVA';es_CO = 'Entrada del IVA';tr = 'KDV girişi';it = 'IVA c\acquisti';de = 'USt.-Eingabe'");
	
	VATIncurredParameter = CompositionTemplate.ParameterValues.Find("VATIncurredText");
	VATIncurredParameter.Value = NStr("en = 'VAT incurred'; ru = 'НДС предъявленный';pl = 'VAT poniesiony';es_ES = 'IVA incurrido';es_CO = 'IVA incurrido';tr = 'Tahakkuk eden KDV';it = 'IVA sostenuta';de = 'Angefallene USt.'");
	
	VATOutputParameter = CompositionTemplate.ParameterValues.Find("VATOutputText");
	VATOutputParameter.Value = NStr("en = 'VAT output'; ru = 'Исходящий НДС';pl = 'VAT należny';es_ES = 'Salida de IVA';es_CO = 'Salida de IVA';tr = 'KDV çıkışı';it = 'IVA c\vendite';de = 'USt.-Ergebnis'");
	
	// Create and initialize a composition processor
	CompositionProcessor = New DataCompositionProcessor;
	CompositionProcessor.Initialize(CompositionTemplate, , DetailsData, True);

	// Create and initialize the result output processor
	OutputProcessor = New DataCompositionResultSpreadsheetDocumentOutputProcessor;
	OutputProcessor.SetDocument(ResultDocument);

	// Indicate the output begin
	OutputProcessor.BeginOutput();
	TableFixed = False;

	ResultDocument.FixedTop = 0;
	// Main cycle of the report output
	While True Do
		// Get the next item of a composition result 
		ResultItem = CompositionProcessor.Next();

		If ResultItem = Undefined Then
			// The next item is not received - end the output cycle
			Break;
		Else
			// Fix header
			If  Not TableFixed 
				AND ResultItem.ParameterValues.Count() > 0 
				AND TypeOf(SettingsComposer.Settings.Structure[0]) <> Type("DataCompositionChart") Then

				TableFixed = True;
				ResultDocument.FixedTop = ResultDocument.TableHeight;

			EndIf;
			// Item is received - output it using an output processor
			OutputProcessor.OutputItem(ResultItem);
		EndIf;
	EndDo;

	OutputProcessor.EndOutput();

EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	ReportSettings = SettingsComposer.GetSettings();
	
	Company = ReportSettings.DataParameters.Items.Find("Company").Value;
	
	If GetFunctionalOption("UseDefaultTypeOfAccounting") Then
		
		VATInput = ReportSettings.DataParameters.Items.Find("VATInputGLAccounts").Value;
		VATOutput = ReportSettings.DataParameters.Items.Find("VATOutputGLAccounts").Value;
		
		If Not ValueIsFilled(VATInput) Then
			
			CommonClientServer.MessageToUser(
				NStr("en = 'VAT input GL accounts are required.'; ru = 'Требуется указать счета учета входящего НДС.';pl = 'Konta księgowe VAT naliczonego są wymagane.';es_ES = 'Se requieren las cuentas del libro mayor de entrada del IVA.';es_CO = 'Se requieren las cuentas del libro mayor de entrada del IVA.';tr = 'KDV girişi muhasebe hesapları gerekli.';it = 'IVA in entrata conti mastro richiesti.';de = 'USt.-Eingabe-Hauptbuch-Konten sind erforderlich.'"));
			
			Cancel = True;
			
		EndIf;
		
		If Not ValueIsFilled(VATOutput) Then
			
			CommonClientServer.MessageToUser(
				NStr("en = 'VAT output GL accounts are required.'; ru = 'Требуется указать счета учета исходящего НДС.';pl = 'Konta księgowe VAT należnego są wymagane.';es_ES = 'Se requieren las cuentas del libro mayor de salida del IVA.';es_CO = 'Se requieren las cuentas del libro mayor de salida del IVA.';tr = 'KDV çıkışı muhasebe hesapları gerekli.';it = 'IVA in uscita conti mastro richiesti.';de = 'USt.-Ergebnis-Hauptbuch-Konten sind erforderlich.'"));
			
			Cancel = True;
			
		EndIf;
		
	EndIf;
	
	If Not ValueIsFilled(Company) Then
		
		CommonClientServer.MessageToUser(
			NStr("en = 'Company is required.'; ru = 'Поле ""Организация"" не заполнено.';pl = 'Wymagana jest firma.';es_ES = 'Se requiere la empresa.';es_CO = 'Se requiere la empresa.';tr = 'İş yeri gerekli.';it = 'E'' necessario specificare l''azienda.';de = 'Firma ist erforderlich.'"));
			
		Cancel = True;
		
	EndIf;
	
EndProcedure

#EndRegion 

#Region Private

Function PrepareReportParameters(ReportSettings)
	
	Title = NStr("en = 'VAT entries reconciliation'; ru = 'Сверка проводок НДС';pl = 'Uzgodnienie wpisów VAT';es_ES = 'Conciliación de las entradas de diario del IVA';es_CO = 'Conciliación de las entradas del IVA';tr = 'KDV girişleri mutabakatı';it = 'Riconciliazione di inserimenti IVA';de = 'USt.-Eintragsausgleich'");
	Company = Catalogs.Companies.EmptyRef();
	BeginOfPeriod = Date(1,1,1);
	EndOfPeriod = Date(1,1,1);
	VATInputGLAccounts = New ValueList;
	VATOutputGLAccounts = New ValueList;
	ShowOnlyDifferences = False;
	
	ParameterCompany = ReportSettings.DataParameters.FindParameterValue(New DataCompositionParameter("Company"));
	If ParameterCompany <> Undefined
		AND ValueIsFilled(ParameterCompany.Value) Then
		
		Company = ParameterCompany.Value;
	EndIf;
	
	ParameterPeriod = ReportSettings.DataParameters.FindParameterValue(New DataCompositionParameter("Period"));
	If ParameterPeriod <> Undefined AND ParameterPeriod.ViewMode = DataCompositionSettingsItemViewMode.QuickAccess Then
		If ParameterPeriod.Use
			AND ValueIsFilled(ParameterPeriod.Value) Then
				
			BeginOfPeriod = ParameterPeriod.Value.StartDate;
			EndOfPeriod  = EndOfDay(ParameterPeriod.Value.EndDate);
		EndIf;
	EndIf;
	
	ParameterVATInputGLAccounts = ReportSettings.DataParameters.FindParameterValue(New DataCompositionParameter("VATInputGLAccounts"));
	If ParameterVATInputGLAccounts <> Undefined Then
		
		VATInputGLAccounts = ParameterVATInputGLAccounts.Value;
	EndIf;
	
	ParameterVATOutputGLAccounts = ReportSettings.DataParameters.FindParameterValue(New DataCompositionParameter("VATOutputGLAccounts"));
	If ParameterVATOutputGLAccounts <> Undefined Then
		
		VATOutputGLAccounts = ParameterVATOutputGLAccounts.Value;
	EndIf;
	
	ParameterShowOnlyDifferences = ReportSettings.DataParameters.FindParameterValue(New DataCompositionParameter("ShowOnlyDifferences"));
	If ParameterCompany <> Undefined Then
		
		ShowOnlyDifferences = ParameterShowOnlyDifferences.Value;
	EndIf;
	
	ReportParameters = New Structure;
	
	ReportParameters.Insert("Company", Company);
	ReportParameters.Insert("BeginOfPeriod", BeginOfPeriod);
	ReportParameters.Insert("EndOfPeriod", EndOfPeriod);
	ReportParameters.Insert("VATInputGLAccounts", VATInputGLAccounts);
	ReportParameters.Insert("VATOutputGLAccounts", VATOutputGLAccounts);
	ReportParameters.Insert("ShowOnlyDifferences", ShowOnlyDifferences);
	
	ReportParameters.Insert("Title", Title);
	ReportParameters.Insert("TitleOutput", False);
	ReportParameters.Insert("ReportId" , "VATEntriesReconciliation");
	ReportParameters.Insert("ReportSettings", ReportSettings);
	
	Return ReportParameters;
	
EndFunction

#EndRegion 

#EndIf