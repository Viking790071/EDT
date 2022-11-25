#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
	
#Region EventHandlers

Procedure OnComposeResult(ResultDocument, DetailsData, StandardProcessing)

	StandardProcessing = False;
	
	SetRequiredSettings();
	
	ReportSettings = SettingsComposer.GetSettings();
	ReportParameters = PrepareReportParameters(ReportSettings);
	
	DriveReports.SetReportAppearanceTemplate(ReportSettings);
	DriveReports.OutputReportTitle(ReportParameters, ResultDocument);
	
	TemplateComposer = New DataCompositionTemplateComposer;
	CompositionTemplate = TemplateComposer.Execute(DataCompositionSchema, ReportSettings, DetailsData);

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

#EndRegion

#Region Private

Function PrepareReportParameters(ReportSettings)
	
	BeginOfPeriod = Date(1,1,1);
	EndOfPeriod  = Date(1,1,1);
	TitleOutput = False;
	Title = NStr("en = 'VAT return'; ru = 'Возврат НДС';pl = 'Zwrot VAT';es_ES = 'Devolución del IVA';es_CO = 'Devolución del IVA';tr = 'KDV iadesi';it = 'Liquidazione IVA';de = 'USt.-Erklärung'");
	
	ParameterPeriod = ReportSettings.DataParameters.FindParameterValue(New DataCompositionParameter("ItmPeriod"));
	If ParameterPeriod <> Undefined AND ParameterPeriod.ViewMode = DataCompositionSettingsItemViewMode.QuickAccess Then
		If ParameterPeriod.Use
			AND ValueIsFilled(ParameterPeriod.Value) Then
			
			BeginOfPeriod = ParameterPeriod.Value.StartDate;
			EndOfPeriod  = ParameterPeriod.Value.EndDate;
		EndIf;
	EndIf;
	
	ParameterOutputTitle = ReportSettings.DataParameters.FindParameterValue(New DataCompositionParameter("TitleOutput"));
	If ParameterOutputTitle <> Undefined
		AND ParameterOutputTitle.Use Then
		
		TitleOutput = ParameterOutputTitle.Value;
	EndIf;
	
	OutputParameter = ReportSettings.OutputParameters.FindParameterValue(New DataCompositionParameter("Title"));
	If OutputParameter <> Undefined
		AND OutputParameter.Use Then
		Title = OutputParameter.Value;
	EndIf;
	
	ReportParameters = New Structure;
	ReportParameters.Insert("BeginOfPeriod", BeginOfPeriod);
	ReportParameters.Insert("EndOfPeriod", EndOfPeriod);
	ReportParameters.Insert("TitleOutput", TitleOutput);
	ReportParameters.Insert("Title", Title);
	ReportParameters.Insert("ReportId", "VATReturn");
	ReportParameters.Insert("ReportSettings", ReportSettings);
		
	Return ReportParameters;
	
EndFunction

Procedure SetRequiredSettings()
	
	DriveReports.SetOutputParameter(SettingsComposer, "TextOutput", NStr("en = 'OUTPUT'; ru = 'ВЫВОД';pl = 'Wyprowadzić';es_ES = 'SALIDA';es_CO = 'SALIDA';tr = 'Çıktı';it = 'Output';de = 'PRODUKTIONSMENGE'"));
	DriveReports.SetOutputParameter(SettingsComposer, "TextInput", NStr("en = 'INPUT'; ru = 'ВВОД';pl = 'Wprowadzić';es_ES = 'ENTRADA';es_CO = 'ENTRADA';tr = 'GİRİŞ';it = 'In entrata';de = 'EINGABE'"));
	DriveReports.SetOutputParameter(SettingsComposer, "TextVATDueOnSales", NStr("en = 'VAT due on sales'; ru = 'НДС с продаж к уплате';pl = 'Podatek VAT należny od sprzedaży';es_ES = 'IVA de ventas';es_CO = 'IVA de ventas';tr = 'Satışlardan dolayı ödenmesi gereken KDV';it = 'IVA dovuta sulle vendite';de = 'USt. fällig auf Verkäufe'"));
	DriveReports.SetOutputParameter(SettingsComposer, "TextVATDueOnMemberStatesAcquisitions", NStr("en = 'VAT due on member states acquisitions'; ru = 'НДС к уплате по закупкам внутри экономического союза';pl = 'Podatek VAT należny od nabycia państw członkowskich';es_ES = 'IVA de las compras de los estados-miembros';es_CO = 'IVA de las compras de los estados-miembros';tr = 'Üye devletlerin satın alımlarından kaynaklanan KDV';it = 'IVA dovuta da acquisizioni da stati membri';de = 'USt. fällig auf Erwerbe in den Mitgliedsstaaten'"));
	DriveReports.SetOutputParameter(SettingsComposer, "TextVATDueOnAdvances", NStr("en = 'VAT due on advances'; ru = 'НДС с авансов к уплате';pl = 'Podatek VAT należny od zaliczek';es_ES = 'IVA de anticipos';es_CO = 'IVA de anticipos';tr = ' Ön ödemelerden doğan KDV';it = 'IVA dovuta sui pagamenti anticipati';de = 'USt. fällig auf Vorauszahlungen'"));
	DriveReports.SetOutputParameter(SettingsComposer, "TotalVATDue", NStr("en = 'TOTAL VAT due (sum of boxes 1, 2, 3)'; ru = 'ИТОГО НДС к уплате (сумма полей 1, 2, 3)';pl = 'OGÓŁEM należny podatek VAT (suma pól 1, 2, 3)';es_ES = 'TOTAL IVA pendiente (suma de las casillas 1, 2, 3)';es_CO = 'TOTAL IVA pendiente (suma de las casillas 1, 2, 3)';tr = 'Vadesi gelen TOPLAM KDV (1, 2, 3 kutularının toplamı)';it = 'IVA TOTALE dovuta (somma dei box 1, 2 e 3)';de = 'USt. fällig (Summe der Kästchen 1, 2, 3)'"));
	DriveReports.SetOutputParameter(SettingsComposer, "TextVATReclaimedOnPurchases", NStr("en = 'VAT reclaimed on purchases'; ru = 'НДС с закупок к возмещению';pl = 'Podatek VAT odzyskany przy zakupie';es_ES = 'IVA de compras';es_CO = 'IVA de compras';tr = 'Satın alımlarda KDV iadesi';it = 'IVA esigibile su acquisti';de = 'USt.-Rückforderung bei Einkäufen'"));
	DriveReports.SetOutputParameter(SettingsComposer, "TextVATReclaimedOnAdvances", NStr("en = 'VAT reclaimed on advances'; ru = 'НДС с авансов к возмещению';pl = 'Podatek VAT odzyskany od zaliczek';es_ES = 'IVA de anticipos';es_CO = 'IVA de anticipos';tr = ' Ön ödemelerde KDV iadesi';it = 'IVA esigibile sui pagamenti anticipati';de = 'USt.-Rückforderung auf Vorauszahlungen'"));
	DriveReports.SetOutputParameter(SettingsComposer, "TextNetVATToBePaid", NStr("en = 'Net VAT to be paid (box 4 - box 5 - box 6 - box 7)'; ru = 'Чистый НДС к уплате (поле 4 - поле 5 - поле 6 - поле 7)';pl = 'Podatek VAT netto do zapłacenia (pole 4 - pole 5 - pole 6 - pole 7)';es_ES = 'IVA neto para pagar (casilla 4 - casilla 5 - casilla 6 - casilla 7)';es_CO = 'IVA neto para pagar (casilla 4 - casilla 5 - casilla 6 - casilla 7)';tr = 'Ödenecek net KDV (kutu 4 - kutu 5 - kutu 6 - kutu 7)';it = 'IVA netta da pagare (box 4 - box 5 - box 6 - box 7)';de = 'USt.-Netto fällig (Kästchen 4 - Kästchen 5 - Kästchen 6- Kästchen 7)'"));
	DriveReports.SetOutputParameter(SettingsComposer, "TextVATNotConfirmed", NStr("en = 'VAT not confirmed'; ru = 'НДС не подтвержден';pl = 'Nie potwierdzono podatku VAT';es_ES = 'IVA no confirmado';es_CO = 'IVA no confirmado';tr = 'Onaylanmayan KDV';it = 'IVA non confermata';de = 'USt. nicht bestätigt'"));
	DriveReports.SetOutputParameter(SettingsComposer, "TextExport", NStr("en = 'Total value of export'; ru = 'Итого стоимость экспорта';pl = 'Całkowita wartość eksportu';es_ES = 'Valor total de exportación';es_CO = 'Valor total de exportación';tr = 'Toplam ihracat tutarı';it = 'Valore totale dell''esportazione';de = 'Export-Gesamtwert'"));
	DriveReports.SetOutputParameter(SettingsComposer, "TextImport", NStr("en = 'VAT reclaimed on import'; ru = 'НДС к возмещению при импорте';pl = 'Podatek VAT odzyskany przy imporcie';es_ES = 'IVA recuperado en la importación';es_CO = 'IVA recuperado en la importación';tr = 'İthalatta geri istenen KDV';it = 'IVA richiesta sull''importazione';de = 'USt. zurückgewonnen an Import'"));
	DriveReports.SetOutputParameter(SettingsComposer, "TextUndefined", "<" + NStr("en = 'Undefined'; ru = 'Неопределено';pl = 'Nieokreślone';es_ES = 'No definido';es_CO = 'No definido';tr = 'Tanımlanmamış';it = 'Non definito';de = 'Nicht definiert'") + ">");
	
EndProcedure

#EndRegion

#EndIf