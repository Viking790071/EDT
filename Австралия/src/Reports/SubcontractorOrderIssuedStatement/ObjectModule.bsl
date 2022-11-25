#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure OnComposeResult(ResultDocument, DetailsData, StandardProcessing)

	StandardProcessing = False;
	UserSettingsModified = False;
	
	SetRequiredSettings(UserSettingsModified);
	
	TemplateComposer = New DataCompositionTemplateComposer;
	ReportSettings = SettingsComposer.GetSettings();
	
	CompositionTemplate = TemplateComposer.Execute(DataCompositionSchema, ReportSettings, DetailsData);
	
	// Create and initialize the processor layout and precheck parameters
	CompositionProcessor = New DataCompositionProcessor;
	CompositionProcessor.Initialize(CompositionTemplate, , DetailsData, True);

	// Create and initialize the result output processor
	OutputProcessor = New DataCompositionResultSpreadsheetDocumentOutputProcessor;
	OutputProcessor.SetDocument(ResultDocument);
	
	// Indicate the output begin
	OutputProcessor.Output(CompositionProcessor);
EndProcedure

#EndRegion

#Region Private

Procedure SetRequiredSettings(UserSettingsModified)
	
	OwnInventory = NStr("en = 'Own inventory'; ru = 'Собственные запасы';pl = 'Zapasy własne';es_ES = 'Inventario propio';es_CO = 'Inventario propio';tr = 'Kendi stokumuz';it = 'Proprie scorte';de = 'Eigenbestände'");
	// begin Drive.FullVersion
	TextRequest= DataCompositionSchema.DataSets.DataSet1.Items.DataSet1.Query;
	TextRequest = StrReplace(TextRequest, "&StrCounterpartyOrdersIssuedBalance", "CASE
							|	WHEN SubcontractorOrdersIssuedBalanceAndTurnovers.SubcontractorOrder.OrderReceived.Counterparty <> VALUE(Catalog.Counterparties.EmptyRef)
							|		THEN SubcontractorOrdersIssuedBalanceAndTurnovers.SubcontractorOrder.OrderReceived.Counterparty
							|	ELSE &StrCounterpartyOrdersIssuedBalance 
							|END");
	DataCompositionSchema.DataSets.DataSet1.Items.DataSet1.Query = TextRequest;
	
	TextRequest = DataCompositionSchema.DataSets.DataSet1.Items.DataSet2.Query;
	TextRequest = StrReplace(TextRequest, "&StrCounterpartySubcontractComponents", "CASE
							|	WHEN SubcontractComponentsBalanceAndTurnovers.SubcontractorOrder.OrderReceived.Counterparty <> VALUE(Catalog.Counterparties.EmptyRef)
							|		THEN SubcontractComponentsBalanceAndTurnovers.SubcontractorOrder.OrderReceived.Counterparty
							|	ELSE &StrCounterpartySubcontractComponents 
							|END");
	
	TextRequest = StrReplace(TextRequest, "&StrCounterpartyStockTransferred", "CASE
							|	WHEN StockTransferredToThirdPartiesBalanceAndTurnovers.Order.OrderReceived.Counterparty <> VALUE(Catalog.Counterparties.EmptyRef)
							|		THEN StockTransferredToThirdPartiesBalanceAndTurnovers.Order.OrderReceived.Counterparty
							|	ELSE &StrCounterpartyStockTransferred 
							|END");
	DataCompositionSchema.DataSets.DataSet1.Items.DataSet2.Query = TextRequest;
	// end Drive.FullVersion
	
	DriveReports.SetOutputParameter(SettingsComposer, "StrCounterpartyOrdersIssuedBalance", " " + OwnInventory);
	DriveReports.SetOutputParameter(SettingsComposer, "StrCounterpartySubcontractComponents", " " +OwnInventory);
	DriveReports.SetOutputParameter(SettingsComposer, "StrCounterpartyStockTransferred", " " + OwnInventory);
	
	UserSettingsModified = True;
EndProcedure

#EndRegion

#EndIf