#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure OnComposeResult(ResultDocument, DetailsData, StandardProcessing)

	StandardProcessing = False;
	
	ReportSettings = SettingsComposer.GetSettings();
	
	ReportParameters = PrepareReportParameters(ReportSettings);
	
	DriveReports.SetReportAppearanceTemplate(ReportSettings);
	DriveReports.OutputReportTitle(ReportParameters, ResultDocument);
	
	ComponentsSourceFilterSetting = ReportSettings.DataParameters.FindParameterValue(New DataCompositionParameter("ComponentsSourceFilter"));
	ComponentsSourceFilter = ComponentsSourceFilterSetting.Value;
	
	If ReportSettings.Structure.Count() Then
		
		FieldsToBeDisabled = New Array;
		If ComponentsSourceFilter = "BOM" Then
			FieldsToBeDisabled.Add("BalanceToProduce");
			FieldsToBeDisabled.Add("TotalToProduce");
			FieldsToBeDisabled.Add("Produced");
			FieldsToBeDisabled.Add("RequiredStockWIP");
		Else
			FieldsToBeDisabled.Add("RequiredStockBOM");
		EndIf;
		
		Try
			DriveReports.DisableSelectionFields(ReportSettings.Structure[0].Columns[0], FieldsToBeDisabled);
		Except
			DriveReports.DisableSelectionFields(ReportSettings.Structure[0], FieldsToBeDisabled);
		EndTry;
		
	EndIf;
	
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

#Region Internal

Procedure DefineFormSettings(Form, VariantKey, Settings) Export
	
	Settings.Events.OnLoadVariantAtServer = True;
	Settings.Events.OnLoadUserSettingsAtServer = True;
	
EndProcedure

Procedure OnLoadVariantAtServer(ReportForm, Settings) Export
	
	ProductionOrder = Undefined;
	ReportForm.ParametersForm.Filter.Property("ProductionOrder", ProductionOrder);
	
	If ValueIsFilled(ProductionOrder) Then
		
		ProductionOrderAttributes = ProductionOrderAttributes(ProductionOrder);
		
		ReportSettings = ReportForm.Report.SettingsComposer.Settings;
		ReportFilter = ReportSettings.Filter;
		
		CommonClientServer.SetFilterItem(ReportFilter, "Company", ProductionOrderAttributes.Company,,, True);
		CommonClientServer.SetFilterItem(ReportFilter,
			"Ownership",
			OrderAvailableOwnership(ProductionOrder),
			DataCompositionComparisonType.InList,
			,
			True,
			DataCompositionSettingsItemViewMode.QuickAccess);
		
	EndIf;
	
EndProcedure

Procedure OnLoadUserSettingsAtServer(ReportForm, Settings) Export
	
	ProductionOrder = Undefined;
	ReportForm.ParametersForm.Filter.Property("ProductionOrder", ProductionOrder);
	
	If ValueIsFilled(ProductionOrder) Then
		
		ProductionOrderAttributes = ProductionOrderAttributes(ProductionOrder);
		
		UserSettings = ReportForm.Report.SettingsComposer.UserSettings;
		
		If UserSettings.AdditionalProperties.Property("FormItems") Then
		
			FormItems = UserSettings.AdditionalProperties.FormItems;
			
			For Each SettingsItem In UserSettings.Items Do
				
				UserSettingID = SettingsItem.UserSettingID;
				FormItem = FormItems.Get(ReportsClientServer.CastIDToName(UserSettingID));
				
				If FormItem <> Undefined Then
					
					If FormItem.Presentation = "Company" Then
						
						SettingsItem.Use = True;
						SettingsItem.RightValue = ProductionOrderAttributes.Company;
						
					ElsIf FormItem.Presentation = "Ownership" Then
						
						SettingsItem.Use = True;
						SettingsItem.RightValue = OrderAvailableOwnership(ProductionOrder);
						
					EndIf;
					
				EndIf;
				
			EndDo;
		
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

Function PrepareReportParameters(ReportSettings)
	
	TitleOutput = False;
	Title = NStr("en = 'Available stock (for production order)'; ru = 'Свободные остатки (для заказа на производство)';pl = 'Dostępne zapasy (dla zlecenia produkcyjnego)';es_ES = 'Stock disponible (para la orden de producción)';es_CO = 'Stock disponible (para la orden de producción)';tr = 'Mevcut stok (üretim emri için)';it = 'Scorte disponibili (per ordine di produzione)';de = 'Verfügbarer Bestand (für Produktionsauftrag)'");
	ParametersToBeIncludedInSelectionText = New Array;
	
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
	ReportParameters.Insert("TitleOutput", TitleOutput);
	ReportParameters.Insert("Title", Title);
	ReportParameters.Insert("ParametersToBeIncludedInSelectionText", ParametersToBeIncludedInSelectionText);
	ReportParameters.Insert("ReportId", "ProductionOrderAvailableStock");
	ReportParameters.Insert("ReportSettings", ReportSettings);
	
	Return ReportParameters;
	
EndFunction

&AtServer
Function ProductionOrderAttributes(ProductionOrder)
	
	ProductionOrderAttributes = Common.ObjectAttributesValues(ProductionOrder, "OperationKind, Company");
	
	Return ProductionOrderAttributes;
	
EndFunction

&AtServer
Function OrderAvailableOwnership(ProductionOrder)
	
	ResultValueList = New ValueList;
	
	Query = New Query;
	Query.Text = 
	"SELECT DISTINCT
	|	InventoryOwnership.Ref AS Ownership
	|FROM
	|	Document.ProductionOrder AS ProductionOrder
	|		INNER JOIN Document.SubcontractorOrderReceived AS SubcontractorOrderReceived
	|		ON ProductionOrder.BasisDocument = SubcontractorOrderReceived.Ref
	|			AND (ProductionOrder.Ref = &ProductionOrder)
	|		INNER JOIN Catalog.InventoryOwnership AS InventoryOwnership
	|		ON (SubcontractorOrderReceived.Counterparty = InventoryOwnership.Counterparty)
	|			AND (InventoryOwnership.Contract.Company = ProductionOrder.Company)
	|WHERE
	|	NOT InventoryOwnership.DeletionMark
	|
	|UNION ALL
	|
	|SELECT DISTINCT
	|	InventoryOwnership.Ref
	|FROM
	|	Catalog.InventoryOwnership AS InventoryOwnership
	|WHERE
	|	InventoryOwnership.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.OwnInventory)
	|	AND &BaseOfOrderIsNotSubcontracting
	|	AND NOT InventoryOwnership.DeletionMark";
	
	Query.SetParameter("BaseOfOrderIsNotSubcontracting", TypeOf(ProductionOrder.BasisDocument) <> Type("DocumentRef.SubcontractorOrderReceived"));
	Query.SetParameter("ProductionOrder", ProductionOrder);
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	While SelectionDetailRecords.Next() Do
		ResultValueList.Add(SelectionDetailRecords.Ownership);
	EndDo;
	
	ResultValueList.Add(Catalogs.InventoryOwnership.EmptyRef());
	
	Return ResultValueList;
	
EndFunction

#EndRegion

#EndIf