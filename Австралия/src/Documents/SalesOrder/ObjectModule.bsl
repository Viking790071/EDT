#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure OnCopy(CopiedObject)
	
	Author = Users.CurrentUser();
	
	FillOnCopy();
	Prepayment.Clear();

	If SerialNumbers.Count() Then
		
		For Each InventoryLine In Inventory Do
			InventoryLine.SerialNumbers = "";
		EndDo;
		
		SerialNumbers.Clear();
		
	EndIf;
	
	If SerialNumbersMaterials.Count() Then
		
		For Each MaterialsLine In Materials Do
			MaterialsLine.SerialNumbers = "";
		EndDo;
		
		SerialNumbersMaterials.Clear();
		
	EndIf;
	
	ForOpeningBalancesOnly = False;
	
EndProcedure

Procedure Filling(FillingData, FillingText, StandardProcessing) Export
	
	If Common.RefTypeValue(FillingData) Then
		ObjectFillingDrive.FillDocument(ThisObject, FillingData, "FillingHandler", "AmountIncludesVAT");
	Else
		ObjectFillingDrive.FillDocument(ThisObject, FillingData);
	EndIf;
	
	If TypeOf(FillingData) = Type("CatalogRef.Counterparties") Then
		
		SalesRep = Common.ObjectAttributeValue(FillingData, "SalesRep");
		
		PaymentTermsServer.FillPaymentCalendarFromContract(ThisObject);
		ShippingAddress = Undefined;
		
	EndIf;
	
	FillByDefault();
	
	If Not ValueIsFilled(DeliveryOption) Or Not ValueIsFilled(ShippingAddress) Then
		DeliveryData = ShippingAddressesServer.GetDeliveryDataForCounterparty(Counterparty);
		If Not ValueIsFilled(DeliveryOption) Or Not ValueIsFilled(ShippingAddress) Then
			DeliveryOption = DeliveryData.DeliveryOption;
		EndIf;
		If Not ValueIsFilled(DeliveryOption) Or Not ValueIsFilled(ShippingAddress) Then
			ShippingAddress = DeliveryData.ShippingAddress;
		EndIf;
	EndIf;
	
	FillSalesRep();
	
EndProcedure

Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Closed And OrderState = DriveReUse.GetOrderStatus("SalesOrderStatuses", "Completed") Then 
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'You cannot make changes to a completed %1.'; ru = 'Нельзя вносить изменения в завершенный %1.';pl = 'Nie możesz wprowadzać zmian w zakończeniu %1.';es_ES = 'No se puede modificar %1 cerrada.';es_CO = 'No se puede modificar %1 cerrada.';tr = 'Tamamlanmış bir %1 üzerinde değişiklik yapılamaz.';it = 'Non potete fare modifiche a un %1 completato.';de = 'Sie können keine Änderungen an einem abgeschlossenen %1 vornehmen.'"), Ref);
		CommonClientServer.MessageToUser(MessageText,,,,Cancel);
		Return;
	EndIf;

	If ShipmentDatePosition = Enums.AttributeStationing.InHeader Then
		For Each TabularSectionRow In Inventory Do
			If TabularSectionRow.ShipmentDate <> ShipmentDate Then
				TabularSectionRow.ShipmentDate = ShipmentDate;
			EndIf;
		EndDo;
	EndIf;
	
	If ShipmentDatePosition = Enums.AttributeStationing.InTabularSection Then
		
		ShipmentDate = DriveServer.ColumnMin(Inventory.Unload(), "ShipmentDate");
				
	EndIf;
	
	If WorkKindPosition = Enums.AttributeStationing.InHeader Then
		For Each TabularSectionRow In Works Do
			TabularSectionRow.WorkKind = WorkKind;
		EndDo;
	EndIf;
	
	If ValueIsFilled(Counterparty)
		AND Not Counterparty.DoOperationsByContracts
		AND Not ValueIsFilled(Contract) Then
		
		Contract = Counterparty.ContractByDefault;
		
	EndIf;
	
	SalesTaxServer.CalculateInventorySalesTaxAmount(Inventory, SalesTax.Total("Amount"));
	
	Totals = DriveServer.CalculateSubtotal(Inventory, AmountIncludesVAT, SalesTax);
	
	If Inventory.Count() > 0 
		Or Not ForOpeningBalancesOnly Then
		
		DocumentAmount = Totals.DocumentTotal;
		
	EndIf;
	
	DocumentTax = Totals.DocumentTax;
	DocumentSubtotal = Totals.DocumentSubtotal;
	
	ChangeDate = CurrentSessionDate();
	
	If NOT ValueIsFilled(DeliveryOption) OR DeliveryOption = Enums.DeliveryOptions.SelfPickup Then
		ClearDeliveryAttributes();
	ElsIf DeliveryOption <> Enums.DeliveryOptions.LogisticsCompany Then
		ClearDeliveryAttributes("LogisticsCompany");
	EndIf;
	
	AdditionalProperties.Insert("WriteMode", WriteMode);
	AdditionalProperties.Insert("Posted", Posted);
	
	// begin Drive.FullVersion
	ExistsProduction = ExistsProductionMethodReplenishmentInInventory();
	// end Drive.FullVersion
	
	If WriteMode = DocumentWriteMode.Posting And QuotationStatuses.CheckQuotationStatusToConverted(BasisDocument) Then
		AdditionalProperties.Insert("QuoteStatusToConverted", True);
	EndIf;
	
EndProcedure

Procedure Posting(Cancel, PostingMode)
	
	If ForOpeningBalancesOnly Then
		Return;
	EndIf;
	
	// Initialization of additional properties for document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	Documents.SalesOrder.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Limit Exceed Control (if the "Override credit limit settings" it not set)
	If Not OverrideCreditLimitSettings Then
		
		DriveServer.CheckLimitsExceed(ThisObject, True, Cancel);
		
	EndIf;
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	DriveServer.ReflectInventoryFlowCalendar(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectSalesOrders(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectInventoryDemand(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectBackorders(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectReservedProducts(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectPaymentCalendar(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectInvoicesAndOrdersPayment(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectUsingPaymentTermsInDocuments(Ref, Cancel);
	
	DriveServer.WriteRecordSets(ThisObject);
	
	Documents.SalesOrder.RunControl(ThisObject, AdditionalProperties, Cancel);
	
	DriveServer.CreateRecordsInTasksRegisters(ThisObject, Cancel);
	DriveServer.ReflectTasksForUpdatingStatuses(Ref, Cancel);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
EndProcedure

Procedure UndoPosting(Cancel)
	
	If ForOpeningBalancesOnly Then
		Return;
	EndIf;
	
	Closed = False;
	
	// Initialization of additional properties to undo document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);
	
	// Control
	Documents.SalesOrder.RunControl(ThisObject, AdditionalProperties, Cancel, True);
	
	DriveServer.ReflectTasksForUpdatingStatuses(Ref, Cancel);
	
EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If ForOpeningBalancesOnly Then
		CheckedAttributes.Clear();
		Return;
	EndIf;
	
	If Not Counterparty.DoOperationsByContracts Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Contract");
	EndIf;
	
	If ShipmentDatePosition = Enums.AttributeStationing.InTabularSection Then
		CheckedAttributes.Delete(CheckedAttributes.Find("ShipmentDate"));
	Else
		CheckedAttributes.Delete(CheckedAttributes.Find("Inventory.ShipmentDate"));
	EndIf;
	
	If Inventory.Total("Reserve") > 0 Then
		
		For Each StringInventory In Inventory Do
		
			If StringInventory.Reserve > 0
			AND Not ValueIsFilled(StructuralUnitReserve) Then
				
				MessageText = NStr("en = 'The reserve warehouse is required.'; ru = 'Не заполнен склад резерва';pl = 'Nie jest wypełniony magazyn rezerwy.';es_ES = 'Se requiere un almacén de reserva.';es_CO = 'Se requiere un almacén de reserva.';tr = 'Yedek ambar gerekiyor.';it = 'È richiesto il magazzino di riserva.';de = 'Das Reservelager ist erforderlich.'");
				DriveServer.ShowMessageAboutError(ThisObject, MessageText, , , "StructuralUnitReserve", Cancel);
				
			EndIf;
		
		EndDo;
	
	EndIf;
	
	If Constants.UseInventoryReservation.Get() Then
		
		If OperationKind = Enums.OperationTypesSalesOrder.OrderForSale Then
			
			For Each StringInventory In Inventory Do
				
				If StringInventory.Reserve > StringInventory.Quantity Then
					
					DriveServer.ShowMessageAboutError(
						ThisObject,
						StringFunctionsClientServer.SubstituteParametersToString(
							NStr("en = 'The quantity of items to be reserved in line #%1 of the Goods list exceeds the available quantity.'; ru = 'В строке №%1 табл. части ""Товары, услуги"" количество резервируемых позиций превышает общее количество запасов.';pl = 'Ilość pozycji do zarezerwowania w wierszu nr %1 listy Towary przekracza dostępną ilość.';es_ES = 'La cantidad de artículos para reservar en la línea #%1 de la lista Mercancías excede la cantidad disponible.';es_CO = 'La cantidad de artículos para reservar en la línea #%1 de la lista Mercancías excede la cantidad disponible.';tr = 'Mallar listesinin no.%1 satırında rezerve edilecek öğe miktarı mevcut miktarı geçiyor.';it = 'La quantità di elementi che devono essere riservati in linea #%1 delle Merci elenco supera la quantità disponibile.';de = 'Die Menge der zu reservierenden Artikel in der Zeile Nr. %1 der Warenliste übersteigt die verfügbare Menge.'"),
							StringInventory.LineNumber),
						"Inventory",
						StringInventory.LineNumber,
						"Reserve",
						Cancel);
					
				EndIf;
				
			EndDo;
			
		EndIf;
		
	EndIf;
	
	If Not Constants.UseSalesOrderStatuses.Get() Then
		
		If Not ValueIsFilled(OrderState) Then
			MessageText = NStr("en = 'The order status is required. Specify the available statuses in Accounting settings > Sales.'; ru = 'Статус не заполнен. Задайте статусы в Параметры учета > Продажи.';pl = 'Wymagany jest status zamówienia. Określ dostępne statusy w menu Ustawienia rachunkowości > Sprzedaż.';es_ES = 'Se requiere el estado de orden. Especificar los estados disponibles en Configuraciones de la contabilidad > Ventas.';es_CO = 'Se requiere el estado de orden. Especificar los estados disponibles en Configuraciones de la contabilidad > Ventas.';tr = 'Emir durumu gereklidir. Mevcut durumlar Muhasebe ayarları > Satış altında belirtin.';it = 'Lo stato dell''ordine è necessario. Specificare gli stati disponibili in Contabilità impostazioni > Vendite.';de = 'Der Status von Kundenauftrag ist erforderlich. Geben Sie die verfügbaren Status unter Buchhaltungseinstellungen > Verkauf an.'");
			DriveServer.ShowMessageAboutError(ThisObject, MessageText, , , "OrderState", Cancel);
		EndIf;
		
	EndIf;
	
	// 100% discount.
	ThereAreManualDiscounts = GetFunctionalOption("UseManualDiscounts");
	ThereAreAutomaticDiscounts = GetFunctionalOption("UseAutomaticDiscounts"); // AutomaticDiscounts
	
	If ThereAreManualDiscounts OR ThereAreAutomaticDiscounts Then
		For Each StringInventory In Inventory Do
			
			// AutomaticDiscounts
			CurAmount					= StringInventory.Price * StringInventory.Quantity;
			ManualDiscountCurAmount		= ?(ThereAreManualDiscounts, ROUND(CurAmount * StringInventory.DiscountMarkupPercent / 100, 2), 0);
			AutomaticDiscountCurAmount	= ?(ThereAreAutomaticDiscounts, StringInventory.AutomaticDiscountAmount, 0);
			CurAmountDiscounts			= ManualDiscountCurAmount + AutomaticDiscountCurAmount;
			
			If StringInventory.DiscountMarkupPercent <> 100 AND CurAmountDiscounts < CurAmount
				AND Not ValueIsFilled(StringInventory.Amount) Then
				
				DriveServer.ShowMessageAboutError(
					ThisObject,
					StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'Amount is required in line #%1 of the Products list.'; ru = 'Не заполнена колонка ""Сумма"" в строке %1 списка ""Товары, работы, услуги"".';pl = 'W wierszu nr %1 listy Towary wymagana jest kwota.';es_ES = 'Se requiere el importe en la línea #%1 de la lista Productos.';es_CO = 'Se requiere el importe en la línea #%1 de la lista Productos.';tr = 'Tutar ürün listesinin no.%1 satırında gereklidir.';it = 'L''importo è richiesto nella linea #%1 dell''elenco Articoli.';de = 'Der Betrag wird in Zeile Nr %1 der Produktliste benötigt.'"),
						StringInventory.LineNumber),
					"Inventory",
					StringInventory.LineNumber,
					"Amount",
					Cancel);
					
			EndIf;
		EndDo;
	EndIf;
	
	If ThereAreManualDiscounts Then
		For Each WorkRow In Works Do
			
			// AutomaticDiscounts
			CurAmount					= WorkRow.Price * WorkRow.Quantity;
			ManualDiscountCurAmount		= ?(ThereAreManualDiscounts, ROUND(CurAmount * WorkRow.DiscountMarkupPercent / 100, 2), 0);
			AutomaticDiscountCurAmount	= ?(ThereAreAutomaticDiscounts, WorkRow.AutomaticDiscountAmount, 0);
			CurAmountDiscounts			= ManualDiscountCurAmount + AutomaticDiscountCurAmount;
			
			If WorkRow.DiscountMarkupPercent <> 100 AND CurAmountDiscounts < CurAmount
				AND Not ValueIsFilled(WorkRow.Amount) Then
				
				DriveServer.ShowMessageAboutError(
					ThisObject,
					StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'Amount is required in line #%1 of the Work list.'; ru = 'В строке #%1 списка Работ требуется указать сумму.';pl = 'W wierszu nr %1 listy Praca wymagana jest kwota.';es_ES = 'Se requiere el importe en la línea #%1 de la Lista trabajo.';es_CO = 'Se requiere el importe en la línea #%1 de la Lista trabajo.';tr = 'Tutar İş listesinin no.%1 satırında gereklidir.';it = 'L''importo è richiesto nella linea #%1 dell''elenco lavori.';de = 'Der Betrag wird in der Zeile Nr %1 der Arbeitsliste benötigt.'"),
						WorkRow.LineNumber),
					"Works",
					WorkRow.LineNumber,
					"Amount",
					Cancel);
				
			EndIf;
		EndDo;
	EndIf;
	
	If Not WorkWithVATServerCall.CompanyIsRegisteredForVAT(Company, Date) Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "CompanyVATNumber");
	EndIf;
	
	// Also check filling of the employees Earnings
	Documents.SalesOrder.ArePerformersWithEmptyEarningSum(Performers);
	
	//Cash flow projection
	Amount = Inventory.Total("Amount") + Works.Total("Amount") + SalesTax.Total("Amount");
	VATAmount = Inventory.Total("VATAmount") + Works.Total("VATAmount");
	
	PaymentTermsServer.CheckRequiredAttributes(ThisObject, CheckedAttributes, Cancel);
	PaymentTermsServer.CheckCorrectPaymentCalendar(ThisObject, Cancel, Amount, VATAmount);
	
	// Bundles
	BundlesServer.CheckTableFilling(ThisObject, "Inventory", Cancel);
	// End Bundles
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	DriveServer.CheckDocumentsReposting(Ref, AdditionalProperties.Posted, Cancel);
	
	If AdditionalProperties.Property("QuoteStatusToConverted") And AdditionalProperties.QuoteStatusToConverted Then
		QuotationStatuses.SetQuotationStatus(BasisDocument, Catalogs.QuotationStatuses.Converted);
	EndIf;
	
EndProcedure

#EndRegion

#Region DocumentFillingProcedures

Procedure FillingHandler(FillingData) Export
	
	If Not ValueIsFilled(FillingData) Or Not Common.RefTypeValue(FillingData) Then
		
		Return;
		
	EndIf;
	
	If TypeOf(FillingData) = Type("DocumentRef.RMARequest") Then
		
		DocumentDate = ?(ValueIsFilled(Date), Date, CurrentSessionDate());
		
		Query = New Query;
		Query.Text =
		"SELECT ALLOWED
		|	ExchangeRateSliceLast.Currency AS Currency,
		|	ExchangeRateSliceLast.Company AS Company,
		|	ExchangeRateSliceLast.Rate AS ExchangeRate,
		|	ExchangeRateSliceLast.Repetition AS Multiplicity
		|INTO TemporaryExchangeRate
		|FROM
		|	InformationRegister.ExchangeRate.SliceLast(&DocumentDate, ) AS ExchangeRateSliceLast
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED
		|	RMARequest.Ref AS BasisDocument,
		|	RMARequest.Company AS Company,
		|	RMARequest.Contract AS Contract,
		|	RMARequest.Counterparty AS Counterparty,
		|	RMARequest.Department AS SalesStructuralUnit,
		|	RMARequest.Location AS ShippingAddress,
		|	RMARequest.ContactPerson AS ContactPerson,
		|	RMARequest.Equipment AS Equipment,
		|	RMARequest.Characteristic AS Characteristic,
		|	RMARequest.ExpectedDate AS ShipmentDate
		|INTO RMARequestTable
		|FROM
		|	Document.RMARequest AS RMARequest
		|WHERE
		|	RMARequest.Ref = &Ref
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED
		|	RMARequestTable.BasisDocument AS BasisDocument,
		|	RMARequestTable.Company AS Company,
		|	RMARequestTable.Contract AS Contract,
		|	RMARequestTable.Counterparty AS Counterparty,
		|	RMARequestTable.SalesStructuralUnit AS SalesStructuralUnit,
		|	RMARequestTable.ShippingAddress AS ShippingAddress,
		|	RMARequestTable.ContactPerson AS ContactPerson,
		|	RMARequestTable.Equipment AS Equipment,
		|	RMARequestTable.Characteristic AS Characteristic,
		|	ISNULL(CounterpartyContracts.SettlementsCurrency, Companies.PresentationCurrency) AS DocumentCurrency,
		|	RMARequestTable.ShipmentDate AS ShipmentDate
		|INTO RMARequestWithCurrency
		|FROM
		|	RMARequestTable AS RMARequestTable
		|		LEFT JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
		|		ON RMARequestTable.Contract = CounterpartyContracts.Ref
		|		LEFT JOIN Catalog.Companies AS Companies
		|		ON RMARequestTable.Company = Companies.Ref
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RMARequestWithCurrency.BasisDocument AS BasisDocument,
		|	RMARequestWithCurrency.Company AS Company,
		|	RMARequestWithCurrency.Contract AS Contract,
		|	RMARequestWithCurrency.Counterparty AS Counterparty,
		|	RMARequestWithCurrency.SalesStructuralUnit AS SalesStructuralUnit,
		|	RMARequestWithCurrency.ShippingAddress AS ShippingAddress,
		|	RMARequestWithCurrency.ContactPerson AS ContactPerson,
		|	RMARequestWithCurrency.Equipment AS Equipment,
		|	RMARequestWithCurrency.Characteristic AS Characteristic,
		|	RMARequestWithCurrency.DocumentCurrency AS DocumentCurrency,
		|	TemporaryExchangeRate.ExchangeRate AS ExchangeRate,
		|	TemporaryExchangeRate.Multiplicity AS Multiplicity,
		|	TemporaryExchangeRate.ExchangeRate AS ContractCurrencyExchangeRate,
		|	TemporaryExchangeRate.Multiplicity AS ContractCurrencyMultiplicity,
		|	RMARequestWithCurrency.ShipmentDate AS ShipmentDate,
		|	CASE
		|		WHEN RMARequestWithCurrency.ShippingAddress <> VALUE(Catalog.ShippingAddresses.EmptyRef)
		|			THEN VALUE(Enum.DeliveryOptions.Delivery)
		|		ELSE VALUE(Enum.DeliveryOptions.SelfPickup)
		|	END AS DeliveryOption
		|FROM
		|	RMARequestWithCurrency AS RMARequestWithCurrency
		|		LEFT JOIN TemporaryExchangeRate AS TemporaryExchangeRate
		|		ON RMARequestWithCurrency.DocumentCurrency = TemporaryExchangeRate.Currency
		|			AND RMARequestWithCurrency.Company = TemporaryExchangeRate.Company";
		
		Query.SetParameter("Ref", FillingData);
		Query.SetParameter("DocumentDate", DocumentDate);
		
		QueryResults = Query.Execute();
		
		Header = QueryResults.Unload();
		
		If Header.Count() > 0 Then
			
			FillPropertyValues(ThisObject, Header[0]);
			
			DeliveryData = ShippingAddressesServer.GetDeliveryAttributesForAddress(Header[0].ShippingAddress);
			
			FillPropertyValues(ThisObject, DeliveryData);
			
			PriceKind			= ?(ValueIsFilled(PriceKind), PriceKind, Catalogs.PriceTypes.Wholesale);
			AmountIncludesVAT	= Common.ObjectAttributeValue(PriceKind, "PriceIncludesVAT");
			VATTaxation			= ?(ValueIsFilled(VATTaxation), VATTaxation, DriveServer.VATTaxation(Company, DocumentDate));
			
			Inventory.Clear();
			
			TabularSectionRow = Inventory.Add();
			
			StructureData = New Structure;
			StructureData.Insert("Company",							Company);
			StructureData.Insert("Products",						Header[0].Equipment);
			StructureData.Insert("Characteristic",					Header[0].Characteristic);
			StructureData.Insert("VATTaxation",						VATTaxation);
			StructureData.Insert("ProcessingDate",					DocumentDate);
			StructureData.Insert("DocumentCurrency",				DocumentCurrency);
			StructureData.Insert("AmountIncludesVAT",				AmountIncludesVAT);
			StructureData.Insert("PriceKind",						PriceKind);
			StructureData.Insert("Factor",							1);
			StructureData.Insert("DiscountMarkupKind",				DiscountMarkupKind);
			StructureData.Insert("DiscountCard",					DiscountCard);
			StructureData.Insert("DiscountPercentByDiscountCard",	DiscountPercentByDiscountCard);
			
			StructureData = GetDataProducts(StructureData);
			
			FillPropertyValues(TabularSectionRow, StructureData);
			
			TabularSectionRow.Quantity				= 1;
			TabularSectionRow.Content				= "";
			TabularSectionRow.ProductsTypeInventory	= StructureData.IsInventoryItem;
			TabularSectionRow.Amount				= TabularSectionRow.Quantity * TabularSectionRow.Price;
			
			If TabularSectionRow.DiscountMarkupPercent = 100 Then
				TabularSectionRow.Amount = 0;
			ElsIf TabularSectionRow.DiscountMarkupPercent <> 0 AND TabularSectionRow.Quantity <> 0 Then
				TabularSectionRow.Amount = TabularSectionRow.Amount * (1 - TabularSectionRow.DiscountMarkupPercent / 100);
			EndIf;
			
			VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.VATRate);
			
			If AmountIncludesVAT Then
				TabularSectionRow.VATAmount = TabularSectionRow.Amount - TabularSectionRow.Amount / ((VATRate + 100) / 100);
			Else
				TabularSectionRow.VATAmount = TabularSectionRow.Amount * VATRate / 100;
			EndIf;
			
			TabularSectionRow.Total = TabularSectionRow.Amount + ?(AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
			
			DocumentAmount = Inventory.Total("Total");
			
			PaymentTermsServer.FillPaymentCalendarFromContract(ThisObject);
			
		EndIf;
		
	ElsIf ValueIsFilled(TabularSectionName(FillingData)) Then
		
		QueryResult = QueryDataForFilling(FillingData).Execute();
		
		If QueryResult.IsEmpty() Then
			Return;
		EndIf;
		
		SelectionHeader = QueryResult.Select();
		SelectionHeader.Next();
		
		FillPropertyValues(ThisObject, SelectionHeader);
		
		If DocumentCurrency <> DriveServer.GetPresentationCurrency(Company) Then
			CurrencyStructure = CurrencyRateOperations.GetCurrencyRate(Date, Contract.SettlementsCurrency, Company);
			ExchangeRate = CurrencyStructure.Rate;
			Multiplicity = CurrencyStructure.Repetition;
			ContractCurrencyExchangeRate = CurrencyStructure.Rate;
			ContractCurrencyMultiplicity = CurrencyStructure.Repetition;
		EndIf;
		
		Inventory.Clear();
		TabularSectionSelection = SelectionHeader[TabularSectionName(FillingData)].Select();
		While TabularSectionSelection.Next() Do
			NewRow	= Inventory.Add();
			FillPropertyValues(NewRow, TabularSectionSelection);
			NewRow.ProductsTypeInventory = (TabularSectionSelection.ProductsProductsType = Enums.ProductsTypes.InventoryItem);
		EndDo;
		
		If GetFunctionalOption("UseAutomaticDiscounts") Then
			SelectionDiscountsMarkups = SelectionHeader.DiscountsMarkups.Select();
			While SelectionDiscountsMarkups.Next() Do
				FillPropertyValues(DiscountsMarkups.Add(), SelectionDiscountsMarkups);
			EndDo;
		EndIf;
		
		// Bundles
		AddedBundles.Clear();
		If FillingData.Metadata().TabularSections.Find("AddedBundles") <> Undefined Then
			
			SelectionAddedBundles = SelectionHeader.AddedBundles.Select();
			
			While SelectionAddedBundles.Next() Do
				FillPropertyValues(AddedBundles.Add(), SelectionAddedBundles);
			EndDo;
			
		EndIf;
		// End Bundles
		
		RecalculateSalesTax();
		
		DocumentAmount = Inventory.Total("Total") + SalesTax.Total("Amount");
		
		// Cash flow projection
		PaymentTermsServer.FillPaymentCalendarFromDocument(ThisObject, FillingData);
		PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(ThisObject);
		
	EndIf;
	
EndProcedure

Function QueryDataForFilling(FillingData)
	
	Wizard = New QuerySchema;
	Batch = Wizard.QueryBatch[0];
	Batch.SelectAllowed = True;
	Operator0 = Batch.Operators[0];
	Operator0.Sources.Add(FillingData.Metadata().FullName());
	For Each HeaderFieldDescription In HeaderFieldsDescription(FillingData) Do
		Operator0.SelectedFields.Add(HeaderFieldDescription.Key);
		If ValueIsFilled(HeaderFieldDescription.Value) Then
			Batch.Columns[Batch.Columns.Count() - 1].Alias = HeaderFieldDescription.Value;
		EndIf;
	EndDo;
	
	For Each CurFieldDescriptionTabularSectionInventory In FieldsDescriptionTabularSectionInventory(FillingData) Do
		Operator0.SelectedFields.Add(
		StringFunctionsClientServer.SubstituteParametersToString(
		"%1.%2",
		TabularSectionName(FillingData),
		CurFieldDescriptionTabularSectionInventory.Key));
		If ValueIsFilled(CurFieldDescriptionTabularSectionInventory.Value) Then
			Batch.Columns[Batch.Columns.Count() - 1].Alias = CurFieldDescriptionTabularSectionInventory.Value;
		EndIf;
	EndDo;
	
	If GetFunctionalOption("UseAutomaticDiscounts") Then
		Operator0.SelectedFields.Add("DiscountsMarkups.ConnectionKey");
		Operator0.SelectedFields.Add("DiscountsMarkups.DiscountMarkup");
		Operator0.SelectedFields.Add("DiscountsMarkups.Amount");
	EndIf;
	
	// Bundles
	If FillingData.Metadata().TabularSections.Find("AddedBundles") <> Undefined Then
		Operator0.SelectedFields.Add("AddedBundles.BundleProduct");
		Operator0.SelectedFields.Add("AddedBundles.BundleCharacteristic");
		Operator0.SelectedFields.Add("AddedBundles.Quantity");
	EndIf;
	// End Bundles
	
	Operator0.Filter.Add("Ref = &Parameter");
	If TypeOf(FillingData) = Type("DocumentRef.Quote") Then
		Operator0.Filter.Add("Inventory.Variant = PreferredVariant");
	EndIf;
	
	Result = New Query(Wizard.GetQueryText());
	Result.SetParameter("Parameter", FillingData);
	
	Return Result;
	
EndFunction

Function TabularSectionName(FillingData)
	
	TabularSectionNames = New Map;
	TabularSectionNames[Type("DocumentRef.Quote")] = "Inventory";
	
	Return TabularSectionNames[TypeOf(FillingData)];
	
EndFunction

Function HeaderFieldsDescription(FillingData)
	
	Result = New Map;
	
	FillingDataMetadata = FillingData.Metadata();
	
	Result.Insert("Ref", "BasisDocument");
	Result.Insert("Company");
	
	AddAttributeIfItIsInDocument(Result, FillingDataMetadata, "CompanyVATNumber");
	AddAttributeIfItIsInDocument(Result, FillingDataMetadata, "DiscountCard");
	AddAttributeIfItIsInDocument(Result, FillingDataMetadata, "DiscountPercentByDiscountCard");
	AddAttributeIfItIsInDocument(Result, FillingDataMetadata, "ExchangeRate");
	AddAttributeIfItIsInDocument(Result, FillingDataMetadata, "Multiplicity");
	AddAttributeIfItIsInDocument(Result, FillingDataMetadata, "ContractCurrencyExchangeRate");
	AddAttributeIfItIsInDocument(Result, FillingDataMetadata, "ContractCurrencyMultiplicity");
	AddAttributeIfItIsInDocument(Result, FillingDataMetadata, "AmountIncludesVAT");
	AddAttributeIfItIsInDocument(Result, FillingDataMetadata, "VATTaxation");
	AddAttributeIfItIsInDocument(Result, FillingDataMetadata, "Contract");
	AddAttributeIfItIsInDocument(Result, FillingDataMetadata, "Counterparty");
	AddAttributeIfItIsInDocument(Result, FillingDataMetadata, "DocumentCurrency");
	AddAttributeIfItIsInDocument(Result, FillingDataMetadata, "BankAccount");
	AddAttributeIfItIsInDocument(Result, FillingDataMetadata, "PettyCash");
	AddAttributeIfItIsInDocument(Result, FillingDataMetadata, "PaymentMethod");
	AddAttributeIfItIsInDocument(Result, FillingDataMetadata, "CashAssetType");
	AddAttributeIfItIsInDocument(Result, FillingDataMetadata, "SalesRep");
	AddAttributeIfItIsInDocument(Result, FillingDataMetadata, "SetPaymentTerms");
	AddAttributeIfItIsInDocument(Result, FillingDataMetadata, "Department", "SalesStructuralUnit");
	AddAttributeIfItIsInDocument(Result, FillingDataMetadata, "SalesTaxRate");
	AddAttributeIfItIsInDocument(Result, FillingDataMetadata, "SalesTaxPercentage");
	
	If GetFunctionalOption("UseAutomaticDiscounts") Then
		Result.Insert("DiscountsAreCalculated");
	EndIf;
	
	Return Result;
	
EndFunction

Procedure AddAttributeIfItIsInDocument(ResultMap, FillingDataMetadata, AttributeName, DocAttributeName = "")
	
	If DocAttributeName = "" Then
		DocAttributeName = AttributeName;
	EndIf;
	
	If Common.HasObjectAttribute(AttributeName, FillingDataMetadata) Then
		ResultMap.Insert(AttributeName, DocAttributeName);
	EndIf;
	
EndProcedure

Function FieldsDescriptionTabularSectionInventory(FillingData)
	
	Result = New Map;
	Result.Insert("Products");
	Result.Insert("Products.ProductsType");
	Result.Insert("Characteristic");
	Result.Insert("Content");
	Result.Insert("MeasurementUnit");
	Result.Insert("Quantity");
	Result.Insert("Price");
	Result.Insert("DiscountMarkupPercent");
	Result.Insert("Amount");
	Result.Insert("VATRate");
	Result.Insert("VATAmount");
	Result.Insert("Total");
	
	If GetFunctionalOption("UseAutomaticDiscounts") Then
		Result.Insert("ConnectionKey");
		Result.Insert("AutomaticDiscountAmount");
		Result.Insert("AutomaticDiscountsPercent");
	EndIf;
	
	// Bundles
	If FillingData.Metadata().TabularSections["Inventory"].Attributes.Find("BundleProduct") <> Undefined Then
		Result.Insert("BundleProduct");
		Result.Insert("BundleCharacteristic");
		Result.Insert("CostShare");
	EndIf;
	// End Bundles
	
	If FillingData.Metadata().TabularSections["Inventory"].Attributes.Find("Taxable") <> Undefined Then
		Result.Insert("Taxable");
	EndIf;
	
	If GetFunctionalOption("UseProjects") Then
		Result.Insert("Project");
	EndIf;
	
	Return Result;
	
EndFunction

Procedure FillTabularSectionPerformersByTeams(ArrayOfTeams, PerformersConnectionKey) Export
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	WorkgroupsContent.Employee AS Employee,
	|	WorkgroupsContent.Employee.Description AS Description,
	|	CompensationPlanSliceLast.EarningAndDeductionType AS EarningAndDeductionType
	|INTO TemporaryTableEmployeesAndEarningDeductionSorts
	|FROM
	|	Catalog.Teams.Content AS WorkgroupsContent
	|		LEFT JOIN InformationRegister.CompensationPlan.SliceLast(
	|				&ToDate,
	|				Company = &Company
	|					AND Actuality
	|					AND EarningAndDeductionType IN (VALUE(Catalog.EarningAndDeductionTypes.PieceRatePay), VALUE(Catalog.EarningAndDeductionTypes.PieceRatePayPercent), VALUE(Catalog.EarningAndDeductionTypes.PieceRatePayFixedAmount))) AS CompensationPlanSliceLast
	|		ON WorkgroupsContent.Employee = CompensationPlanSliceLast.Employee
	|WHERE
	|	WorkgroupsContent.Ref IN(&ArrayOfTeams)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	TemporaryTableEmployeesAndEarningDeductionSorts.Employee AS Employee,
	|	TemporaryTableEmployeesAndEarningDeductionSorts.Description AS Description,
	|	TemporaryTableEmployeesAndEarningDeductionSorts.EarningAndDeductionType AS EarningAndDeductionType,
	|	1 AS LPF,
	|	CompensationPlanSliceLast.Amount * CASE
	|		WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|			THEN DocumentCurrencyRate.Rate * EarningCurrencyRate.Repetition / (EarningCurrencyRate.Rate * DocumentCurrencyRate.Repetition)
	|		WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|			THEN EarningCurrencyRate.Rate * DocumentCurrencyRate.Repetition / (DocumentCurrencyRate.Rate * EarningCurrencyRate.Repetition)
	|	END AS AmountEarningDeduction
	|FROM
	|	TemporaryTableEmployeesAndEarningDeductionSorts AS TemporaryTableEmployeesAndEarningDeductionSorts
	|		LEFT JOIN InformationRegister.CompensationPlan.SliceLast(
	|				&ToDate,
	|				Company = &Company
	|					AND Actuality) AS CompensationPlanSliceLast
	|		ON TemporaryTableEmployeesAndEarningDeductionSorts.Employee = CompensationPlanSliceLast.Employee
	|			AND TemporaryTableEmployeesAndEarningDeductionSorts.EarningAndDeductionType = CompensationPlanSliceLast.EarningAndDeductionType
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&ToDate, Company = &Company) AS EarningCurrencyRate
	|		ON (CompensationPlanSliceLast.Currency = EarningCurrencyRate.Currency),
	|	InformationRegister.ExchangeRate.SliceLast(
	|			&ToDate,
	|			Currency = &DocumentCurrency
	|				AND Company = &Company) AS DocumentCurrencyRate
	|
	|ORDER BY
	|	Description";
	
	Query.SetParameter("ToDate"             , Date);
	Query.SetParameter("Company"            , Company);
	Query.SetParameter("ExchangeRateMethod" , DriveServer.GetExchangeMethod(Company));
	Query.SetParameter("DocumentCurrency"   , DocumentCurrency);
	Query.SetParameter("ArrayOfTeams"       , ArrayOfTeams);
	
	ResultsArray = Query.ExecuteBatch();
	EmployeesTable = ResultsArray[1].Unload();
	
	If PerformersConnectionKey = Undefined Then
		
		For Each TabularSectionRow In Works Do
			
			If TabularSectionRow.Products.ProductsType = Enums.ProductsTypes.Work Then
				
				For Each TSRow In EmployeesTable Do
					
					NewRow = Performers.Add();
					FillPropertyValues(NewRow, TSRow);
					NewRow.ConnectionKey = TabularSectionRow.ConnectionKey;
					
				EndDo;
				
			EndIf;
			
		EndDo;
		
	Else
		
		For Each TSRow In EmployeesTable Do
			
			NewRow = Performers.Add();
			FillPropertyValues(NewRow, TSRow);
			NewRow.ConnectionKey = PerformersConnectionKey;
			
		EndDo;
		
	EndIf;
	
EndProcedure

Procedure FillColumnReserveByBalances() Export
	
	Inventory.LoadColumn(New Array(Inventory.Count()), "Reserve");
	
	TempTablesManager = New TempTablesManager;
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	Query.Text =
	"SELECT
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch
	|INTO TemporaryTableInventory
	|FROM
	|	&TableInventory AS TableInventory
	|WHERE
	|	TableInventory.ProductsTypeInventory
	|	AND NOT TableInventory.DropShipping";
	
	Query.SetParameter("TableInventory", Inventory.Unload());
	Query.Execute();
	
	Query.Text =
	"SELECT ALLOWED
	|	InventoryBalances.Company AS Company,
	|	InventoryBalances.StructuralUnit AS StructuralUnit,
	|	InventoryBalances.Products AS Products,
	|	InventoryBalances.Characteristic AS Characteristic,
	|	InventoryBalances.Batch AS Batch,
	|	SUM(InventoryBalances.QuantityBalance) AS QuantityBalance
	|FROM
	|	(SELECT
	|		InventoryBalances.Company AS Company,
	|		InventoryBalances.StructuralUnit AS StructuralUnit,
	|		InventoryBalances.Products AS Products,
	|		InventoryBalances.Characteristic AS Characteristic,
	|		InventoryBalances.Batch AS Batch,
	|		InventoryBalances.QuantityBalance AS QuantityBalance
	|	FROM
	|		AccumulationRegister.Inventory.Balance(
	|				,
	|				(Company, StructuralUnit, Products, Characteristic, Batch, Ownership) IN
	|					(SELECT
	|						&Company,
	|						&StructuralUnit,
	|						TableInventory.Products,
	|						TableInventory.Characteristic,
	|						TableInventory.Batch,
	|						&OwnInventory
	|					FROM
	|						TemporaryTableInventory AS TableInventory)) AS InventoryBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		ReservedProductsBalances.Company,
	|		ReservedProductsBalances.StructuralUnit,
	|		ReservedProductsBalances.Products,
	|		ReservedProductsBalances.Characteristic,
	|		ReservedProductsBalances.Batch,
	|		-ReservedProductsBalances.QuantityBalance
	|	FROM
	|		AccumulationRegister.ReservedProducts.Balance(
	|				,
	|				(Company, StructuralUnit, Products, Characteristic, Batch) IN
	|					(SELECT
	|						&Company,
	|						&StructuralUnit,
	|						TableInventory.Products,
	|						TableInventory.Characteristic,
	|						TableInventory.Batch
	|					FROM
	|						TemporaryTableInventory AS TableInventory)) AS ReservedProductsBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsReservedProducts.Company,
	|		DocumentRegisterRecordsReservedProducts.StructuralUnit,
	|		DocumentRegisterRecordsReservedProducts.Products,
	|		DocumentRegisterRecordsReservedProducts.Characteristic,
	|		DocumentRegisterRecordsReservedProducts.Batch,
	|		DocumentRegisterRecordsReservedProducts.Quantity
	|	FROM
	|		AccumulationRegister.ReservedProducts AS DocumentRegisterRecordsReservedProducts
	|	WHERE
	|		DocumentRegisterRecordsReservedProducts.Recorder = &Ref
	|		AND DocumentRegisterRecordsReservedProducts.Period <= &Period
	|		AND (DocumentRegisterRecordsReservedProducts.Company, DocumentRegisterRecordsReservedProducts.StructuralUnit, DocumentRegisterRecordsReservedProducts.Products, DocumentRegisterRecordsReservedProducts.Characteristic, DocumentRegisterRecordsReservedProducts.Batch) IN
	|				(SELECT
	|					&Company,
	|					&StructuralUnit,
	|					TableInventory.Products,
	|					TableInventory.Characteristic,
	|					TableInventory.Batch
	|				FROM
	|					TemporaryTableInventory AS TableInventory)) AS InventoryBalances
	|
	|GROUP BY
	|	InventoryBalances.Company,
	|	InventoryBalances.StructuralUnit,
	|	InventoryBalances.Products,
	|	InventoryBalances.Characteristic,
	|	InventoryBalances.Batch";
	
	Query.SetParameter("Period", Date);
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("Company", DriveServer.GetCompany(Company));
	Query.SetParameter("StructuralUnit", StructuralUnitReserve);
	Query.SetParameter("OwnInventory", Catalogs.InventoryOwnership.OwnInventory());
	
	TableOfPeriods = New ValueTable();
	TableOfPeriods.Columns.Add("ShipmentDate");
	TableOfPeriods.Columns.Add("StringInventory");
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	While Selection.Next() Do
		
		StructureForSearch = New Structure;
		StructureForSearch.Insert("Products", Selection.Products);
		StructureForSearch.Insert("Characteristic", Selection.Characteristic);
		StructureForSearch.Insert("Batch", Selection.Batch);
		StructureForSearch.Insert("DropShipping", False);
		
		ArrayOfRowsInventory = Inventory.FindRows(StructureForSearch);
		For Each StringInventory In ArrayOfRowsInventory Do
			NewRow = TableOfPeriods.Add();
			NewRow.ShipmentDate = StringInventory.ShipmentDate;
			NewRow.StringInventory = StringInventory;
		EndDo;
		
		TotalBalance = Selection.QuantityBalance;
		TableOfPeriods.Sort("ShipmentDate");
		For Each TableOfPeriodsRow In TableOfPeriods Do
			StringInventory = TableOfPeriodsRow.StringInventory;
			TotalBalance = ?(TypeOf(StringInventory.MeasurementUnit) = Type("CatalogRef.UOMClassifier"), TotalBalance, TotalBalance / StringInventory.MeasurementUnit.Factor);
			If StringInventory.Quantity >= TotalBalance Then
				StringInventory.Reserve = TotalBalance;
				TotalBalance = 0;
			Else
				StringInventory.Reserve = StringInventory.Quantity;
				TotalBalance = TotalBalance - StringInventory.Quantity;
				TotalBalance = ?(TypeOf(StringInventory.MeasurementUnit) = Type("CatalogRef.UOMClassifier"), TotalBalance, TotalBalance * StringInventory.MeasurementUnit.Factor);
			EndIf;
		EndDo;
		
		TableOfPeriods.Clear();
		
	EndDo;
	
EndProcedure

Procedure FillOnCopy()
	
	If Constants.UseSalesOrderStatuses.Get() Then
		SettingValue = DriveReUse.GetValueByDefaultUser(Author, "StatusOfNewSalesOrder");
		If ValueIsFilled(SettingValue) Then
			If OrderState <> SettingValue Then
				OrderState = SettingValue;
			EndIf;
		Else
			OrderState = Catalogs.SalesOrderStatuses.Open;
		EndIf;
	Else
		OrderState = Constants.SalesOrdersInProgressStatus.Get();
	EndIf;
	
	Closed = False;
	
	If Not ValueIsFilled(Date) Then
		Date = CurrentSessionDate();
	EndIf;
	
	ShipmentDate = Date;
	For Each Row In Inventory Do
		Row.ShipmentDate = ShipmentDate;
	EndDo;
	
EndProcedure

Procedure FillByDefault()

	If Constants.UseSalesOrderStatuses.Get() Then
		SettingValue = DriveReUse.GetValueByDefaultUser(Users.CurrentUser(), "StatusOfNewSalesOrder");
		If ValueIsFilled(SettingValue) Then
			If OrderState <> SettingValue Then
				OrderState = SettingValue;
			EndIf;
		Else
			OrderState = Catalogs.SalesOrderStatuses.Open;
		EndIf;
	Else
		OrderState = Constants.SalesOrdersInProgressStatus.Get();
	EndIf;

EndProcedure

Function GetDataProducts(StructureData)
	
	ProductsAttributes = Common.ObjectAttributesValues(StructureData.Products, "MeasurementUnit, VATRate, ProductsType");
	
	StructureData.Insert("MeasurementUnit", ProductsAttributes.MeasurementUnit);
	StructureData.Insert("IsInventoryItem", (ProductsAttributes.ProductsType = Enums.ProductsTypes.InventoryItem));
	
	If StructureData.Property("VATTaxation") 
		AND NOT StructureData.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
		
		If StructureData.VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT Then
			StructureData.Insert("VATRate", Catalogs.VATRates.Exempt);
		Else
			StructureData.Insert("VATRate", Catalogs.VATRates.ZeroRate);
		EndIf;
		
	ElsIf ValueIsFilled(StructureData.Products) And ValueIsFilled(ProductsAttributes.VATRate) Then
		StructureData.Insert("VATRate", ProductsAttributes.VATRate);
	Else
		StructureData.Insert("VATRate", InformationRegisters.AccountingPolicy.GetDefaultVATRate(, StructureData.Company));
	EndIf;
	
	If StructureData.Property("Characteristic") Then
		StructureData.Insert("Specification", DriveServer.GetDefaultSpecification(StructureData.Products, StructureData.Characteristic));
	Else
		StructureData.Insert("Specification", DriveServer.GetDefaultSpecification(StructureData.Products));
	EndIf;
	
	If StructureData.Property("PriceKind") Then
		
		If Not StructureData.Property("Characteristic") Then
			StructureData.Insert("Characteristic", Catalogs.ProductsCharacteristics.EmptyRef());
		EndIf;
		
		Price = DriveServer.GetProductsPriceByPriceKind(StructureData);
		StructureData.Insert("Price", Price);
		
	Else
		
		StructureData.Insert("Price", 0);
		
	EndIf;
	
	If StructureData.Property("DiscountMarkupKind") 
		AND ValueIsFilled(StructureData.DiscountMarkupKind) Then
		StructureData.Insert("DiscountMarkupPercent", 
			Common.ObjectAttributeValue(StructureData.DiscountMarkupKind, "Percent"));
	Else
		StructureData.Insert("DiscountMarkupPercent", 0);
	EndIf;
		
	If StructureData.Property("DiscountPercentByDiscountCard") 
		AND ValueIsFilled(StructureData.DiscountCard) Then
		CurPercent = StructureData.DiscountMarkupPercent;
		StructureData.Insert("DiscountMarkupPercent", CurPercent + StructureData.DiscountPercentByDiscountCard);
	EndIf;
	
	Return StructureData;
	
EndFunction

Procedure FillTabularSectionBySpecification(NodesBillsOfMaterialStack, NodesTable = Undefined) Export
	
	TempTablesManager = New TempTablesManager;
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	Query.Text =
	"SELECT
	|	TableInventory.LineNumber AS LineNumber,
	|	TableInventory.Quantity AS Quantity,
	|	TableInventory.Factor AS Factor,
	|	TableInventory.Specification AS Specification
	|INTO TemporaryTableInventory
	|FROM
	|	&TableInventory AS TableInventory
	|WHERE
	|	TableInventory.Specification <> VALUE(Catalog.BillsOfMaterials.EmptyRef)";
	
	If NodesTable = Undefined Then
		ConsumerMaterials.Clear();
		TableInventory = Inventory.Unload();
		Array = New Array();
		Array.Add(Type("Number"));
		TypeDescriptionC = New TypeDescription(Array, , ,New NumberQualifiers(10,3));
		TableInventory.Columns.Add("Factor", TypeDescriptionC);
		For Each StringProducts In TableInventory Do
			If ValueIsFilled(StringProducts.MeasurementUnit)
				AND TypeOf(StringProducts.MeasurementUnit) = Type("CatalogRef.UOM") Then
				StringProducts.Factor = StringProducts.MeasurementUnit.Factor;
			Else
				StringProducts.Factor = 1;
			EndIf;
		EndDo;
		NodesTable = TableInventory.CopyColumns("LineNumber,Quantity,Factor,Specification");
		Query.SetParameter("TableInventory", TableInventory);
	Else
		Query.SetParameter("TableInventory", NodesTable);
	EndIf;
	
	Query.Execute();
	
	Query.Text =
	"SELECT
	|	MIN(TableInventory.LineNumber) AS ProductionLineNumber,
	|	TableInventory.Specification AS ProductionSpecification,
	|	MIN(TableMaterials.LineNumber) AS StructureLineNumber,
	|	TableMaterials.ContentRowType AS ContentRowType,
	|	TableMaterials.Products AS Products,
	|	CASE
	|		WHEN UseCharacteristics.Value
	|			THEN TableMaterials.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	SUM(TableMaterials.Quantity / TableMaterials.Ref.Quantity * TableInventory.Factor * TableInventory.Quantity) AS Quantity,
	|	TableMaterials.MeasurementUnit AS MeasurementUnit,
	|	CASE
	|		WHEN TableMaterials.ContentRowType = VALUE(Enum.BOMLineType.Node)
	|				AND VALUETYPE(TableMaterials.MeasurementUnit) = TYPE(Catalog.UOM)
	|				AND TableMaterials.MeasurementUnit <> VALUE(Catalog.UOM.EmptyRef)
	|			THEN TableMaterials.MeasurementUnit.Factor
	|		ELSE 1
	|	END AS Factor,
	|	TableMaterials.CostPercentage AS CostPercentage,
	|	TableMaterials.Specification AS Specification
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|		LEFT JOIN Catalog.BillsOfMaterials.Content AS TableMaterials
	|		ON TableInventory.Specification = TableMaterials.Ref,
	|	Constant.UseCharacteristics AS UseCharacteristics
	|WHERE
	|	TableMaterials.Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|
	|GROUP BY
	|	TableInventory.Specification,
	|	TableMaterials.ContentRowType,
	|	TableMaterials.Products,
	|	TableMaterials.MeasurementUnit,
	|	CASE
	|		WHEN TableMaterials.ContentRowType = VALUE(Enum.BOMLineType.Node)
	|				AND VALUETYPE(TableMaterials.MeasurementUnit) = TYPE(Catalog.UOM)
	|				AND TableMaterials.MeasurementUnit <> VALUE(Catalog.UOM.EmptyRef)
	|			THEN TableMaterials.MeasurementUnit.Factor
	|		ELSE 1
	|	END,
	|	TableMaterials.CostPercentage,
	|	TableMaterials.Specification,
	|	CASE
	|		WHEN UseCharacteristics.Value
	|			THEN TableMaterials.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END
	|
	|ORDER BY
	|	ProductionLineNumber,
	|	StructureLineNumber";
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		If Selection.ContentRowType = Enums.BOMLineType.Node Then
			NodesTable.Clear();
			If Not NodesBillsOfMaterialStack.Find(Selection.Specification) = Undefined Then
				MessageText = NStr("en = 'During filling in of the Specification materials
				                   |tabular section a recursive item occurrence was found'; 
				                   |ru = 'При попытке заполнить табличную
				                   |часть Материалы по спецификации, обнаружено рекурсивное вхождение элемента';
				                   |pl = 'Podczas wypełniania sekcji tabelarycznej
				                   |""Specyfikacja materiałowa"", wykryto rekursywne włączenie elementu';
				                   |es_ES = 'Rellenando la sección tabular
				                   |de Materiales de Especificación, una ocurrencia del artículo recursivo se ha encontrado';
				                   |es_CO = 'Rellenando la sección tabular
				                   |de Materiales de Especificación, una ocurrencia del artículo recursivo se ha encontrado';
				                   |tr = 'Spesifikasyon materyalleri sekme kısmının doldurulması sırasında
				                   |, tekrarlamalı bir öğe oluşumu bulundu.';
				                   |it = 'Durante la compilazione delle Distinte Base dei materiali
				                   |sono stati trovati elementi ricorsivi nella sezione tabellare';
				                   |de = 'Beim Ausfüllen des
				                   |Tabellenbereichs Spezifikationsmaterialien wurde ein rekursives Element gefunden'")+" "+Selection.Products+" "+NStr("en = 'in BOM'; ru = 'в спецификации';pl = 'w zestawieniu materiałowym';es_ES = 'en BOM';es_CO = 'en BOM';tr = 'ürün reçetesinde';it = 'in Distinta Base';de = 'in der Stückliste'")+" "+Selection.ProductionSpecification+"
									|The operation failed.";
				Raise MessageText;
			EndIf;
			NodesBillsOfMaterialStack.Add(Selection.Specification);
			NewRow = NodesTable.Add();
			FillPropertyValues(NewRow, Selection);
			FillTabularSectionBySpecification(NodesBillsOfMaterialStack, NodesTable);
		Else
			NewRow = ConsumerMaterials.Add();
			FillPropertyValues(NewRow, Selection);
		EndIf;
	EndDo;
	
	NodesBillsOfMaterialStack.Clear();
	ConsumerMaterials.GroupBy("Products, Characteristic, MeasurementUnit", "Quantity");
	
EndProcedure

Procedure RecalculateSalesTax() Export
	
	SalesTax.Clear();
	
	If ValueIsFilled(SalesTaxRate) Then
		
		InventoryTaxable = Inventory.Unload(New Structure("Taxable", True));
		AmountTaxable = InventoryTaxable.Total("Total");
		
		If AmountTaxable <> 0 Then
			
			Combined = Common.ObjectAttributeValue(SalesTaxRate, "Combined");
			
			If Combined Then
				
				Query = New Query;
				Query.Text =
				"SELECT
				|	SalesTaxRatesTaxComponents.Component AS SalesTaxRate,
				|	SalesTaxRatesTaxComponents.Rate AS SalesTaxPercentage,
				|	CAST(&AmountTaxable * SalesTaxRatesTaxComponents.Rate / 100 AS NUMBER(15, 2)) AS Amount
				|FROM
				|	Catalog.SalesTaxRates.TaxComponents AS SalesTaxRatesTaxComponents
				|WHERE
				|	SalesTaxRatesTaxComponents.Ref = &Ref";
				
				Query.SetParameter("Ref", SalesTaxRate);
				Query.SetParameter("AmountTaxable", AmountTaxable);
				
				SalesTax.Load(Query.Execute().Unload());
				
			Else
				
				NewRow = SalesTax.Add();
				NewRow.SalesTaxRate = SalesTaxRate;
				NewRow.SalesTaxPercentage = SalesTaxPercentage;
				NewRow.Amount = Round(AmountTaxable * SalesTaxPercentage / 100, 2, RoundMode.Round15as20);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	SalesTaxServer.CalculateInventorySalesTaxAmount(Inventory, SalesTax.Total("Amount"));
	
EndProcedure

// begin Drive.FullVersion
Function ExistsProductionMethodReplenishmentInInventory()
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	TRUE AS VrtField
	|FROM
	|	Catalog.Products AS Products
	|WHERE
	|	Products.ReplenishmentMethod = VALUE(Enum.InventoryReplenishmentMethods.Production)
	|	AND Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|	AND Products.Ref IN(&InventoryProducts)";
	
	Query.SetParameter("InventoryProducts", Inventory.UnloadColumn("Products"));
	QueryResult = Query.Execute();
	
	Return Not QueryResult.IsEmpty();
	
EndFunction
// end Drive.FullVersion

Procedure FillSalesRep()
	
	If ValueIsFilled(SalesRep) Then
		Return;
	EndIf;
	
	If ValueIsFilled(ShippingAddress) Then
		SalesRep = Common.ObjectAttributeValue(ShippingAddress, "SalesRep");
	EndIf;
	
	If Not ValueIsFilled(SalesRep) And ValueIsFilled(Counterparty) Then
		SalesRep = Common.ObjectAttributeValue(Counterparty, "SalesRep");
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

Procedure ClearDeliveryAttributes(FieldsToClear = "")
	
	ClearStructure = New Structure;
	ClearStructure.Insert("ShippingAddress",	Undefined);
	ClearStructure.Insert("ContactPerson",		Undefined);
	ClearStructure.Insert("Incoterms",			Undefined);
	ClearStructure.Insert("DeliveryTimeFrom",	Undefined);
	ClearStructure.Insert("DeliveryTimeTo",		Undefined);
	ClearStructure.Insert("GoodsMarking",		Undefined);
	ClearStructure.Insert("LogisticsCompany",	Undefined);
	
	If IsBlankString(FieldsToClear) Then
		FillPropertyValues(ThisObject, ClearStructure);
	Else
		FillPropertyValues(ThisObject, ClearStructure, FieldsToClear);
	EndIf;
	
EndProcedure

#EndRegion

#EndIf
