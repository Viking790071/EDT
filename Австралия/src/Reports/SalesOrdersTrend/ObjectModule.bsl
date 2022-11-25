#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure OnComposeResult(ResultDocument, DetailsData, StandardProcessing)

	StandardProcessing = False;
	
	ReportSettings = SettingsComposer.GetSettings();
	
	SettingsParameterValue = ReportSettings.DataParameters.FindParameterValue(New DataCompositionParameter("StatusShipment"));
	If SettingsParameterValue <> Undefined Then
		SettingsParameterValue.Value = FilterByShippingState;
		SettingsParameterValue.Use = True;
		SettingsParameterValue.UserSettingPresentation = "Shipment state";
	EndIf;
	
	SettingsParameterValue = ReportSettings.DataParameters.FindParameterValue(New DataCompositionParameter("PaymentState"));
	If SettingsParameterValue <> Undefined Then
		SettingsParameterValue.Value = FilterByPaymentState;
		SettingsParameterValue.Use = True;
		SettingsParameterValue.UserSettingPresentation = "Payment state";
	EndIf;
	
	ReportParameters = PrepareReportParameters(ReportSettings);
	
	SetDataParameters(ReportSettings);
	
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
	
	TitleOutput = False;
	Title = "Shipping and payment by orders";
	ParametersToBeIncludedInSelectionText = New Array;
	
	ShipmentStatusParameter = ReportSettings.DataParameters.FindParameterValue(New DataCompositionParameter("StatusShipment"));
	If ShipmentStatusParameter <> Undefined
		AND ShipmentStatusParameter.Use Then
		
		ParametersToBeIncludedInSelectionText.Add(ShipmentStatusParameter);
	EndIf;
	
	ParameterPaymentState = ReportSettings.DataParameters.FindParameterValue(New DataCompositionParameter("PaymentState"));
	If ParameterPaymentState <> Undefined
		AND ParameterPaymentState.Use Then
		
		ParametersToBeIncludedInSelectionText.Add(ParameterPaymentState);
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
	ReportParameters.Insert("TitleOutput"              , TitleOutput);
	ReportParameters.Insert("Title"                      , Title);
	ReportParameters.Insert("ParametersToBeIncludedInSelectionText", ParametersToBeIncludedInSelectionText);
	ReportParameters.Insert("ReportId"            , "SalesOrdersTrend");
	ReportParameters.Insert("ReportSettings"	              , ReportSettings);
		
	Return ReportParameters;
	
EndFunction

Procedure SetDataParameters(ReportSettings)
	
	ParametersMap = New Map;
	ParametersMap.Insert(New DataCompositionParameter("TextNotShipped"), NStr("en = 'Not shipped'; ru = 'Не отгруженные';pl = 'Niewysłane';es_ES = 'No enviados';es_CO = 'No enviados';tr = 'Sevk edilmemiş';it = 'Non spedito';de = 'Nicht versandt'"));
	ParametersMap.Insert(New DataCompositionParameter("TextFullyShipped"), NStr("en = 'Fully shipped'; ru = 'Отгруженные полностью';pl = 'Wysłane w całości';es_ES = 'Enviado plenamente';es_CO = 'Enviado plenamente';tr = 'Tamamen sevk edilmiş';it = 'Spedito completamente';de = 'Komplett versandt'"));
	ParametersMap.Insert(New DataCompositionParameter("TextPartiallyShipped"), NStr("en = 'Partially shipped'; ru = 'Отгруженные частично';pl = 'Wysłane częściowo';es_ES = 'Expedido parcialmente';es_CO = 'Expedido parcialmente';tr = 'Kısmen sevk edilen';it = 'Spedito parzialmente';de = 'Teilweise versandt'"));
	ParametersMap.Insert(New DataCompositionParameter("TextUnpaid"), NStr("en = 'Unpaid'; ru = 'Неоплаченные';pl = 'Niezapłacone';es_ES = 'No pagados';es_CO = 'No pagados';tr = 'Ödenmemiş';it = 'Non pagato';de = 'Unbezahlte'"));
	ParametersMap.Insert(New DataCompositionParameter("TextCompletelyPaid"), NStr("en = 'Completely paid'; ru = 'Полностью оплаченные';pl = 'Całkowicie wypłacone';es_ES = 'Pagado completamente';es_CO = 'Pagado completamente';tr = 'Tamamen ödenmiş';it = 'Pagato interamente';de = 'Völlig bezahlt'"));
	ParametersMap.Insert(New DataCompositionParameter("TextPartiallyPaid"), NStr("en = 'Partially paid'; ru = 'Оплаченные частично';pl = 'Częściowo wypłacone';es_ES = 'Pagado parcialmente';es_CO = 'Pagado parcialmente';tr = 'Kısmen ödenen';it = 'Pagato parzialmente';de = 'Teilweise bezahlt'"));
	
	For Each MapItem In ParametersMap Do
		If ReportSettings.DataParameters.FindParameterValue(MapItem.Key) <> Undefined Then
			ReportSettings.DataParameters.SetParameterValue(MapItem.Key, MapItem.Value);
		EndIf;
	EndDo;
	
EndProcedure

#EndRegion

#EndIf