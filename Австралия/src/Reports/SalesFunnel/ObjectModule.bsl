#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure OnComposeResult(ResultDocument, DetailsData, StandardProcessing)
	StandardProcessing = False;
	UserSettingsModified = False;
	
	SetRequiredSettings(UserSettingsModified);
	
	ArrayHeaderResources = New Array;
	ReportSettings = SettingsComposer.GetSettings();
	
	AdditionalProperties = SettingsComposer.UserSettings.AdditionalProperties;
	
	// Drill down vision
	DrillDown = AdditionalProperties.Property("DrillDown")
		AND AdditionalProperties.DrillDown;
		
	FromDrillDown = False;
	For Each StructureItem In ReportSettings.Structure Do
		If StructureItem.Name = "DrillDown" AND StructureItem.Use Then
			FromDrillDown = True;
			Break;
		EndIf;
	EndDo;
	
	If DrillDown OR FromDrillDown Then
		For Each StructureItem In ReportSettings.Structure Do
			StructureItem.Use = (StructureItem.Name = "DrillDown");
		EndDo;
		If DrillDown Then
			AdditionalProperties.DrillDown = False;
		EndIf;
	EndIf;
	
	// Filter
	If AdditionalProperties.Property("FilterStructure") Then
		For Each FilterItem In AdditionalProperties.FilterStructure Do
			CommonClientServer.SetFilterItem(ReportSettings.Filter,
				FilterItem.Key,
				FilterItem.Value);
		EndDo;
		AdditionalProperties.Delete("FilterStructure");
	EndIf;
		
	TemplateComposer = New DataCompositionTemplateComposer;
	CompositionTemplate = TemplateComposer.Execute(DataCompositionSchema, ReportSettings, DetailsData);

	// Create and initialize the processor layout and precheck parameters
	CompositionProcessor = New DataCompositionProcessor;
	CompositionProcessor.Initialize(CompositionTemplate, , DetailsData, True);

	// Create and initialize the result output processor
	OutputProcessor = New DataCompositionResultSpreadsheetDocumentOutputProcessor;
	OutputProcessor.SetDocument(ResultDocument);
	
	// Indicate the output begin
	OutputProcessor.Output(CompositionProcessor);
	
	// Edge inside
	For Each ChartItem In ResultDocument.Drawings Do
		If TypeOf(ChartItem.Object) = Type("Chart") Then
			ChartItem.Object.LabelLocation = ChartLabelLocation.EdgeInside;
		EndIf;
	EndDo;
	
EndProcedure

Procedure SetRequiredSettings(UserSettingsModified)
	
	DriveReports.SetOutputParameter(SettingsComposer, "StateConvertedLeads", NStr("en = 'Converted leads'; ru = '????????, ?????????????? ??????????????????';pl = 'Przekszta??cone leady';es_ES = 'Leads convertidos';es_CO = 'Leads convertidos';tr = 'D??n????t??r??len m????teri adaylar??';it = 'Potenziali Clienti convertiti';de = 'Konvertierte Leads'") + ",");
	DriveReports.SetOutputParameter(SettingsComposer, "StateNewLeads", NStr("en = 'New leads'; ru = '?????????? ????????';pl = 'Nowe leady';es_ES = 'Nuevos leads';es_CO = 'Nuevos leads';tr = 'Yeni m????teri adaylar??';it = 'Nuovi potenziali Clienti';de = 'Neue Leads'") + ",");
	DriveReports.SetOutputParameter(SettingsComposer, "StateFirstOrder", NStr("en = 'First order'; ru = '???????????? ??????????';pl = 'Pierwsze zam??wienie';es_ES = 'La primera orden';es_CO = 'La primera orden';tr = '??lk sipari??';it = 'Primo ordine';de = 'Erstbestellung'") + ",");
	DriveReports.SetOutputParameter(SettingsComposer, "StateQuotationSent", NStr("en = 'Quotation sent'; ru = '???????????????????????? ?????????????????????? ????????????????????';pl = 'Wys??ano ofert??';es_ES = 'Presupuesto enviado';es_CO = 'Presupuesto enviado';tr = 'Teklif g??nderildi';it = 'Preventivo inviato';de = 'Angebot gesendet'") + ",");
	DriveReports.SetOutputParameter(SettingsComposer, "StateSold", NStr("en = 'Sold'; ru = '??????????????';pl = 'Sprzedane';es_ES = 'Vendido';es_CO = 'Vendido';tr = 'Sat??lm????';it = 'Venduto';de = 'Verkauft'") + ",");
	DriveReports.SetOutputParameter(SettingsComposer, "StateRepetetiveSale", NStr("en = 'Repetetive sale'; ru = '?????????????????????????? ??????????????';pl = 'Powtarzalna sprzeda??';es_ES = 'Ventas repetitivas';es_CO = 'Ventas repetitivas';tr = 'Tekrarlanan sat????';it = 'Vendita ripetitiva';de = 'Wiederholter Verkauf'") + ",");
	DriveReports.SetOutputParameter(SettingsComposer, "Total", " " + NStr("en = 'total'; ru = '??????????';pl = 'Razem';es_ES = 'total';es_CO = 'total';tr = 'toplam';it = 'totale';de = 'gesamt'") + ": ");
	
	UserSettingsModified = True;
	
EndProcedure

#EndRegion

#EndIf
