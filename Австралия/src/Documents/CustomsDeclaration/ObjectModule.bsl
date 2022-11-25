#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure Filling(FillingData, FillingText, StandardProcessing) Export
	
	FillingStrategy = New Map;
	FillingStrategy[Type("Structure")] = "FillByStructure";
	FillingStrategy[Type("DocumentRef.SupplierInvoice")] = "FillBySupplierInvoice";
	
	ObjectFillingDrive.FillDocument(ThisObject, FillingData, FillingStrategy);
	
EndProcedure

Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If ValueIsFilled(Supplier)
		And Not Supplier.DoOperationsByContracts
		And Not ValueIsFilled(SupplierContract) Then
		
		SupplierContract = Supplier.ContractByDefault;
		
	EndIf;
	
	// Change of approved documents
	AccountingApprovalServer.BeforeWriteAtServer(ThisObject, Cancel);
	// End Change of approved documents
	
	AdditionalProperties.Insert("WriteMode", WriteMode);
	AdditionalProperties.Insert("Posted", Posted);
	
	InventoryOwnershipServer.FillMainTableColumn(ThisObject, WriteMode, Cancel);
	
EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If Not ValueIsFilled(Counterparty) Or Not Common.ObjectAttributeValue(Counterparty, "DoOperationsByContracts") Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Contract");
	EndIf;
	
	If Not ValueIsFilled(Supplier) Or Not Common.ObjectAttributeValue(Supplier, "DoOperationsByContracts") Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "SupplierContract");
	EndIf;
	
	If Not OtherDutyToExpenses Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "OtherDutyGLAccount");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "ExpenseItem");
	EndIf;
	
	SearchStructure = New Structure("CommodityGroup");
	InventoryTotals = New Structure;
	
	For Each CGRow In CommodityGroups Do
		
		SearchStructure.CommodityGroup = CGRow.CommodityGroup;
		
		InventoryTotals.Insert("CustomsValue", 0);
		InventoryTotals.Insert("DutyAmount", 0);
		InventoryTotals.Insert("OtherDutyAmount", 0);
		InventoryTotals.Insert("ExciseAmount", 0);
		InventoryTotals.Insert("VATAmount", 0);
		
		InventoryRows = Inventory.FindRows(SearchStructure);
		
		For Each InventoryRow In InventoryRows Do
			
			InventoryTotals.CustomsValue = InventoryTotals.CustomsValue + InventoryRow.CustomsValue;
			InventoryTotals.DutyAmount = InventoryTotals.DutyAmount + InventoryRow.DutyAmount;
			InventoryTotals.OtherDutyAmount = InventoryTotals.OtherDutyAmount + InventoryRow.OtherDutyAmount;
			InventoryTotals.ExciseAmount = InventoryTotals.ExciseAmount + InventoryRow.ExciseAmount;
			InventoryTotals.VATAmount = InventoryTotals.VATAmount + InventoryRow.VATAmount;
			
		EndDo;
		
		MessagePattern = NStr("en = 'The ""%1"" in the line #%2 of the ""Commodity groups"" list does not match the respective inventory total.'; ru = '""%1"" в строке %2 списка групп номенклатуры не совпадает с соответствующим остатком запасов.';pl = 'W ""%1"" wierszu nr%2 listy ""Grupy towarów"" nie jest zgodna z odpowiednią ilością zapasów.';es_ES = 'El ""%1"" en la línea #%2 de la lista de ""Grupos de comodidad"" no coincide con el total respectivo del inventario.';es_CO = 'El ""%1"" en la línea #%2 de la lista de ""Grupos de comodidad"" no coincide con el total respectivo del inventario.';tr = '""Emtia grupları"" listesinin #%2 satırındaki ""%1"", ilgili stok toplamıyla eşleşmiyor.';it = 'Il ""%1"" nella linea #%2 del elenco ""Gruppi merceologici"" non corrisponde il rispettivo totale scorte';de = '""%1"" in der Zeile Nr %2 der Liste ""Warengruppen"" stimmt nicht mit der jeweiligen Gesamtbestand überein.'");
		
		DocMetadataAttributes = Metadata().TabularSections.CommodityGroups.Attributes;
		
		For Each InvTotal In InventoryTotals Do
			
			If InvTotal.Value <> CGRow[InvTotal.Key] Then
				
				FieldPresentation = DocMetadataAttributes[InvTotal.Key].Presentation();
				ErrorText = StringFunctionsClientServer.SubstituteParametersToString(MessagePattern, FieldPresentation, Format(CGRow.LineNumber, "NZ=0; NG=0"));
				Field = CommonClientServer.PathToTabularSection("CommodityGroups", CGRow.LineNumber, InvTotal.Key);
				CommonClientServer.MessageToUser(ErrorText, ThisObject, Field, , Cancel);
				
			EndIf;
			
		EndDo;
		
	EndDo;
	
	InvoicesData = InvoicesDataToBeChecked();
	
	If ValueIsFilled(Date) And InvoicesData.InvoicesDates.Count() Then
		
		MaxInvoiceDate = InvoicesData.InvoicesDates[0].InvoiceDate;
		
		If ValueIsFilled(MaxInvoiceDate) Then
			
			MessagePattern = NStr("en = 'The customs declaration date should be greater than the invoice date (%1).'; ru = 'Дата таможенной декларации должна быть позже, чем дата инвойса (%1).';pl = 'Data zgłoszenia celnego powinna być większa niż data faktury (%1).';es_ES = 'La fecha de la declaración aduanera tienen que ser mayor de la fecha de la factura (%1).';es_CO = 'La fecha de la declaración aduanera tienen que ser mayor de la fecha de la factura (%1).';tr = 'Gümrük beyannamesi tarihi, fatura tarihinden (%1) ileri olmalıdır.';it = 'La data della dichiarazione doganale deve essere maggiore della data della fattura (%1).';de = 'Das Datum der Zollanmeldung sollte größer als das Rechnungsdatum sein (%1).'");
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(MessagePattern, Format(MaxInvoiceDate, "DLF=D"));
			CommonClientServer.MessageToUser(ErrorText, ThisObject, "Date", , Cancel);
			
		EndIf;
		
	EndIf;
	
	MessagePattern = NStr("en = 'The warehouse in the line #%1 of the ""Inventory"" list does not match the invoice.'; ru = 'Склад в строке %1 списка ""ТМЦ"" не совпадает с данными инвойса.';pl = 'Magazyn na wierszu %1 listy ""Zapasy"" nie pasuje do faktury.';es_ES = 'El almacén en la línea #%1 de la lista ""Inventario"" no coincide con la factura.';es_CO = 'El almacén en la línea #%1 de la lista ""Inventario"" no coincide con la factura.';tr = '""Stok"" listesinin #%1 numaralı satırındaki ambar faturayla eşleşmiyor.';it = 'Il magazzino nella linea #%1 del elenco ""Scorte"" non corrisponde con la fattura.';de = 'Das Lager in der Zeile Nr %1 der Liste ""Bestand"" stimmt nicht mit der Rechnung überein.'");
	
	For Each InventoryRow In InvoicesData.StructuralUnitsMatch Do
		
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(MessagePattern, Format(InventoryRow.LineNumber, "NZ=0; NG=0"));
		Field = CommonClientServer.PathToTabularSection("Inventory", InventoryRow.LineNumber, "StructuralUnit");
		CommonClientServer.MessageToUser(ErrorText, ThisObject, Field, , Cancel);
		
	EndDo;
	
	MessagePattern = NStr("en = 'The ""Advance invoicing"" attribute in the line #%1 of the ""Inventory"" list does not match the invoice.'; ru = 'Признак ""Отложенная отгрузка"" в строке %1 списка ""ТМЦ"" не совпадает с данными счета.';pl = 'Atrybut „Fakturowanie zaliczkowe” we wierszu nr%1 listy „Zapasy” nie pasuje do faktury.';es_ES = 'La ""Factura avanzada"" en la línea #%1 de la lista ""Inventario"" no coincide con la factura.';es_CO = 'La ""Factura Anticipada"" en la línea #%1 de la lista ""Inventario"" no coincide con la factura.';tr = '""Stok"" listesinin #%1 satırındaki ""Avans faturalama"" özniteliği faturayla eşleşmiyor.';it = 'L''attributo ""Fatturazione anticipata"" nella linea #%1 dell''elenco ""Scorte"" non corrisponde alla fattura.';de = 'Das Attribut ""Rechnung per Vorkasse"" in der Zeile Nr %1 der Liste ""Bestand"" stimmt nicht mit der Rechnung überein.'");
	
	For Each InventoryRow In InvoicesData.AdvanceInvoicingMatch Do
		
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(MessagePattern, Format(InventoryRow.LineNumber, "NZ=0; NG=0"));
		Field = CommonClientServer.PathToTabularSection("Inventory", InventoryRow.LineNumber, "AdvanceInvoicing");
		CommonClientServer.MessageToUser(ErrorText, ThisObject, Field, , Cancel);
		
	EndDo;
	
	If ValueIsFilled(VATIsDue) Then
		
		RegisteredForVAT = InformationRegisters.AccountingPolicy.GetAccountingPolicy(Date, Company).RegisteredForVAT;
		
		If Not RegisteredForVAT And VATIsDue <> Enums.VATDueOnCustomsClearance.OnTheSupply Then
			
			ErrorText = NStr("en = 'VAT return is not applicable for non VAT-registered entities.'; ru = 'Возврат НДС недоступен для компаний, по которым не ведется учет НДС.';pl = 'Zwrot VAT nie dotyczy podmiotów niezarejestrowanych VAT.';es_ES = 'Devolución del IVA no se aplica para las entidades de no IVA registradas.';es_CO = 'Devolución del IVA no se aplica para las entidades de no IVA registradas.';tr = 'KDV kaydı olmayan işletmeler için KDV iadesi geçerli değildir.';it = 'Il rimborso IVA non è applicavile per le entità registrate esenti IVA';de = 'Die USt.-Erklärungen gelten nicht für nicht umsatzsteuerpflichtige Firmen.'");
			
			CommonClientServer.MessageToUser(ErrorText, ThisObject, "VATIsDue", , Cancel);
			
		EndIf;
		
		If Not RegisteredForVAT Then
			DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "CompanyVATNumber");
		EndIf;
		
	EndIf;
	
	If Not ValueIsFilled(Counterparty) Then
		
		If OperationKind = Enums.OperationTypesCustomsDeclaration.Customs Then
			CounterpartyTitle = NStr("en = 'Customs'; ru = 'Таможне';pl = 'Urząd celny';es_ES = 'Aduana';es_CO = 'Aduana';tr = 'Gümrük';it = 'Dogana';de = 'Zoll'");
		ElsIf OperationKind = Enums.OperationTypesCustomsDeclaration.Broker Then
			CounterpartyTitle = NStr("en = 'Customs broker'; ru = 'Брокеру';pl = 'Agent celny';es_ES = 'Agente aduanero';es_CO = 'Agente aduanero';tr = 'Gümrük komisyoncusu';it = 'Broker doganale';de = 'Zollagent'");
		ElsIf OperationKind = Enums.OperationTypesCustomsDeclaration.CustomsBroker Then
			CounterpartyTitle = NStr("en = 'Customs/Customs broker'; ru = 'Таможня/Брокер';pl = 'Urząd/agent celny';es_ES = 'Aduana/Agente aduanero';es_CO = 'Aduana/Agente aduanero';tr = 'Gümrük/Gümrük komisyoncusu';it = 'Dogana/Broker doganale';de = 'Zoll/Zollagent'");
		EndIf;
		
		MessagePattern = NStr("en = '""%1"" is required.'; ru = 'Поле ""%1"" не заполнено.';pl = '""%1"" jest wymagane.';es_ES = 'Se requiere ""%1"".';es_CO = 'Se requiere ""%1"".';tr = '""%1"" gerekli.';it = 'È richiesto ""%1"".';de = '""%1"" ist benötigt.'");
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(MessagePattern, CounterpartyTitle);
		CommonClientServer.MessageToUser(ErrorText, ThisObject, "Counterparty", , Cancel);
		
	EndIf;
	
	BatchesServer.CheckFilling(ThisObject, Cancel);
	
EndProcedure

Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting.
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Accounting templates properties initialization.
	AccountingTemplatesPosting.InitializeAccountingTemplatesProperties(Ref, AdditionalProperties, Cancel);
	If AdditionalProperties.ForPosting.AccountingTemplatesPostingUnavailable Then
		Return;
	EndIf;
	
	// Document data initialization.
	Documents.CustomsDeclaration.InitializeDocumentData(Ref, AdditionalProperties);
	
	AccountingTemplatesPosting.CheckEntriesAccounts(AdditionalProperties, Cancel);
	
	// Preparation of records sets.
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	DriveServer.ReflectGoodsAwaitingCustomsClearance(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectInventory(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectGoodsInvoicedNotReceived(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpenses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountsPayable(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectMiscellaneousPayable(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectVATInput(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectVATOutput(AdditionalProperties, RegisterRecords, Cancel);
	
	// Accounting
	DriveServer.ReflectAccountingJournalEntries(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntriesSimple(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntriesCompound(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingEntriesData(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectDocumentAccountingEntriesStatuses(ThisObject, AdditionalProperties, RegisterRecords, Cancel);
	
	// Offline registers
	DriveServer.ReflectLandedCosts(AdditionalProperties, RegisterRecords, Cancel);
	
	// Record of the records sets.
	DriveServer.WriteRecordSets(ThisObject);
	
	// Control of occurrence of a negative balance.
	Documents.CustomsDeclaration.RunControl(Ref, AdditionalProperties, Cancel);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
	AccountingTemplatesPosting.CheckForDuplicateAccountingEntries(Ref, Company, Date, Cancel);
	
	// Subordinate documents
	If Not Cancel Then
		
		AccountingTemplatesPosting.CreateRefreshTransactionDocumentsByMode(
			Ref, DocumentWriteMode.Posting, DeletionMark, Company, Date, AdditionalProperties);
		
	EndIf;

EndProcedure

Procedure UndoPosting(Cancel)
	
	// Initialization of additional properties for document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);
	
	// Control of occurrence of a negative balance.
	Documents.CustomsDeclaration.RunControl(Ref, AdditionalProperties, Cancel, True);
	
	AccountingTemplatesPosting.CheckForDuplicateAccountingEntries(Ref, Company, Date, Cancel);
	
	// Subordinate documents
	If Not Cancel Then
		
		AccountingTemplatesPosting.CreateRefreshTransactionDocumentsByMode(
			Ref, DocumentWriteMode.UndoPosting, DeletionMark, Company, Date, AdditionalProperties);
			
		DriveServer.ReflectDeletionAccountingTransactionDocuments(Ref);
		
	EndIf;

EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	DriveServer.CheckDocumentsReposting(Ref, AdditionalProperties.Posted, Cancel);
	
	If Not Cancel And AdditionalProperties.WriteMode = DocumentWriteMode.Write Then
		
		AccountingTemplatesPosting.CreateRefreshTransactionDocumentsByMode(
			Ref, DocumentWriteMode.Write, DeletionMark, Company, Date, AdditionalProperties);
		
	EndIf;

EndProcedure

Procedure OnCopy(CopiedObject)
	
	Author = Users.CurrentUser();
	ExternalDocumentNumber = "";
	ExternalDocumentDate = "";
	
EndProcedure

#EndRegion

#Region Private

#Region DocumentFillingProcedures

Procedure FillByStructure(FillingData) Export
	
	If FillingData.Property("ArrayOfSupplierInvoices") Then
		FillBySupplierInvoice(FillingData);
	EndIf;
	
EndProcedure

Procedure FillBySupplierInvoice(FillingData) Export
	
	// Document basis and document setting.
	If TypeOf(FillingData) = Type("Structure") And FillingData.Property("ArrayOfSupplierInvoices") Then
		InvoicesArray = FillingData.ArrayOfSupplierInvoices;
	Else
		InvoicesArray = New Array;
		InvoicesArray.Add(FillingData.Ref);
	EndIf;
	
	If Not ValueIsFilled(DocumentCurrency) Then
		DocumentCurrency = DriveReUse.GetFunctionalCurrency();
	EndIf;
	If Not ValueIsFilled(Company) And InvoicesArray.Count() > 0 Then
		Company = Common.ObjectAttributeValue(InvoicesArray[0], "Company");
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	SupplierInvoiceHeader.Company AS Company,
	|	SupplierInvoiceHeader.CompanyVATNumber AS CompanyVATNumber,
	|	SupplierInvoiceHeader.Counterparty AS Counterparty,
	|	SupplierInvoiceHeader.Contract AS Contract,
	|	SupplierInvoiceHeader.StructuralUnit AS StructuralUnit,
	|	SupplierInvoiceHeader.VATTaxation AS VATTaxation,
	|	SupplierInvoiceHeader.DocumentCurrency AS DocumentCurrency,
	|	CASE
	|		WHEN SupplierInvoiceHeader.OperationKind = VALUE(Enum.OperationTypesSupplierInvoice.AdvanceInvoice)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS AdvanceInvoicing,
	|	SupplierInvoiceHeader.Ref AS Ref,
	|	SupplierInvoiceHeader.Posted AS Posted
	|INTO TT_SupplierInvoiceHeader
	|FROM
	|	Document.SupplierInvoice AS SupplierInvoiceHeader
	|WHERE
	|	SupplierInvoiceHeader.Ref IN(&InvoicesArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_SupplierInvoiceHeader.Company AS Company,
	|	TT_SupplierInvoiceHeader.CompanyVATNumber AS CompanyVATNumber,
	|	TT_SupplierInvoiceHeader.Counterparty AS Supplier,
	|	TT_SupplierInvoiceHeader.Contract AS SupplierContract,
	|	TT_SupplierInvoiceHeader.StructuralUnit AS StructuralUnit,
	|	TT_SupplierInvoiceHeader.VATTaxation AS VATTaxation,
	|	TT_SupplierInvoiceHeader.Ref AS Ref,
	|	TT_SupplierInvoiceHeader.Posted AS Posted
	|FROM
	|	TT_SupplierInvoiceHeader AS TT_SupplierInvoiceHeader
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Inventory.Products AS Products,
	|	Inventory.Characteristic AS Characteristic,
	|	Inventory.Batch AS Batch,
	|	Inventory.Invoice AS Invoice,
	|	Inventory.Order AS Order,
	|	Inventory.Quantity AS Quantity,
	|	Inventory.CommodityGroup AS CommodityGroup
	|INTO TT_Inventory
	|FROM
	|	&Inventory AS Inventory
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CommodityGroups.CommodityGroup AS CommodityGroup
	|INTO TT_CommodityGroups
	|FROM
	|	&CommodityGroups AS CommodityGroups
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ISNULL(MAX(CommodityGroups.CommodityGroup), 0) AS CommodityGroup
	|FROM
	|	(SELECT
	|		TT_CommodityGroups.CommodityGroup AS CommodityGroup
	|	FROM
	|		TT_CommodityGroups AS TT_CommodityGroups
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		TT_Inventory.CommodityGroup
	|	FROM
	|		TT_Inventory AS TT_Inventory) AS CommodityGroups
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	GoodsBalances.Products AS Products,
	|	GoodsBalances.Characteristic AS Characteristic,
	|	GoodsBalances.Batch AS Batch,
	|	GoodsBalances.Invoice AS Invoice,
	|	GoodsBalances.Order AS Order,
	|	SUM(GoodsBalances.Quantity) AS Quantity
	|INTO TT_GoodsBalances
	|FROM
	|	(SELECT
	|		GoodsBalances.Products AS Products,
	|		GoodsBalances.Characteristic AS Characteristic,
	|		GoodsBalances.Batch AS Batch,
	|		GoodsBalances.SupplierInvoice AS Invoice,
	|		GoodsBalances.PurchaseOrder AS Order,
	|		GoodsBalances.QuantityBalance AS Quantity
	|	FROM
	|		AccumulationRegister.GoodsAwaitingCustomsClearance.Balance(
	|				,
	|				SupplierInvoice IN
	|					(SELECT
	|						TT_SupplierInvoiceHeader.Ref
	|					FROM
	|						TT_SupplierInvoiceHeader)) AS GoodsBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		Inventory.Products,
	|		Inventory.Characteristic,
	|		Inventory.Batch,
	|		Inventory.Invoice,
	|		Inventory.Order,
	|		-Inventory.Quantity
	|	FROM
	|		TT_Inventory AS Inventory
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		GoodsRecords.Products,
	|		GoodsRecords.Characteristic,
	|		GoodsRecords.Batch,
	|		GoodsRecords.SupplierInvoice,
	|		GoodsRecords.PurchaseOrder,
	|		CASE
	|			WHEN GoodsRecords.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN ISNULL(GoodsRecords.Quantity, 0)
	|			ELSE -ISNULL(GoodsRecords.Quantity, 0)
	|		END
	|	FROM
	|		AccumulationRegister.GoodsAwaitingCustomsClearance AS GoodsRecords
	|	WHERE
	|		GoodsRecords.Recorder = &Ref) AS GoodsBalances
	|
	|GROUP BY
	|	GoodsBalances.Products,
	|	GoodsBalances.Characteristic,
	|	GoodsBalances.Batch,
	|	GoodsBalances.Invoice,
	|	GoodsBalances.Order
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	TT_SupplierInvoiceHeader.Ref AS Ref,
	|	TT_SupplierInvoiceHeader.StructuralUnit AS StructuralUnit,
	|	TT_SupplierInvoiceHeader.AdvanceInvoicing AS AdvanceInvoicing,
	|	SupplierInvoiceInventory.Products AS Products,
	|	SupplierInvoiceInventory.Characteristic AS Characteristic,
	|	SupplierInvoiceInventory.Batch AS Batch,
	|	SupplierInvoiceInventory.Ownership AS Ownership,
	|	SupplierInvoiceInventory.Order AS Order,
	|	SUM(SupplierInvoiceInventory.Quantity * ISNULL(UOM.Factor, 1)) AS Quantity,
	|	SUM(CASE
	|			WHEN TT_SupplierInvoiceHeader.DocumentCurrency = &DocumentCurrency
	|				THEN SupplierInvoiceInventory.Total
	|			WHEN DC_ExchangeRate.Rate = 0
	|					OR SI_ExchangeRate.Repetition = 0
	|				THEN 0
	|			ELSE SupplierInvoiceInventory.Total * CASE
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|						THEN SI_ExchangeRate.Rate * DC_ExchangeRate.Repetition / (DC_ExchangeRate.Rate * SI_ExchangeRate.Repetition)
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|						THEN 1 / (SI_ExchangeRate.Rate * DC_ExchangeRate.Repetition / (DC_ExchangeRate.Rate * SI_ExchangeRate.Repetition))
	|				END
	|		END) AS Total
	|INTO TT_AmountsData
	|FROM
	|	TT_SupplierInvoiceHeader AS TT_SupplierInvoiceHeader
	|		INNER JOIN Document.SupplierInvoice.Inventory AS SupplierInvoiceInventory
	|		ON TT_SupplierInvoiceHeader.Ref = SupplierInvoiceInventory.Ref
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON (SupplierInvoiceInventory.MeasurementUnit = UOM.Ref)
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&RatesDate, ) AS SI_ExchangeRate
	|		ON TT_SupplierInvoiceHeader.DocumentCurrency = SI_ExchangeRate.Currency
	|			AND TT_SupplierInvoiceHeader.Company = SI_ExchangeRate.Company
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&RatesDate, ) AS DC_ExchangeRate
	|		ON (DC_ExchangeRate.Currency = &DocumentCurrency)
	|			AND TT_SupplierInvoiceHeader.Company = DC_ExchangeRate.Company
	|
	|GROUP BY
	|	SupplierInvoiceInventory.Products,
	|	SupplierInvoiceInventory.Characteristic,
	|	SupplierInvoiceInventory.Batch,
	|	SupplierInvoiceInventory.Ownership,
	|	SupplierInvoiceInventory.Order,
	|	TT_SupplierInvoiceHeader.StructuralUnit,
	|	TT_SupplierInvoiceHeader.AdvanceInvoicing,
	|	TT_SupplierInvoiceHeader.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	GoodsBalances.Products AS Products,
	|	GoodsBalances.Characteristic AS Characteristic,
	|	GoodsBalances.Batch AS Batch,
	|	TT_AmountsData.Ownership AS Ownership,
	|	GoodsBalances.Invoice AS Invoice,
	|	GoodsBalances.Order AS Order,
	|	GoodsBalances.Quantity AS Quantity,
	|	CASE
	|		WHEN ISNULL(TT_AmountsData.Quantity, 0) = 0
	|			THEN 0
	|		ELSE CAST(GoodsBalances.Quantity * ISNULL(TT_AmountsData.Total, 0) / TT_AmountsData.Quantity AS NUMBER(15, 2))
	|	END AS CustomsValue,
	|	TT_AmountsData.StructuralUnit AS StructuralUnit,
	|	TT_AmountsData.AdvanceInvoicing AS AdvanceInvoicing,
	|	CatalogProducts.CountryOfOrigin AS Origin,
	|	CatalogProducts.HSCode AS HSCode
	|FROM
	|	TT_GoodsBalances AS GoodsBalances
	|		LEFT JOIN Catalog.Products AS CatalogProducts
	|		ON GoodsBalances.Products = CatalogProducts.Ref
	|		LEFT JOIN TT_AmountsData AS TT_AmountsData
	|		ON GoodsBalances.Invoice = TT_AmountsData.Ref
	|			AND GoodsBalances.Order = TT_AmountsData.Order
	|			AND GoodsBalances.Products = TT_AmountsData.Products
	|			AND GoodsBalances.Characteristic = TT_AmountsData.Characteristic
	|			AND GoodsBalances.Batch = TT_AmountsData.Batch
	|WHERE
	|	GoodsBalances.Quantity > 0
	|TOTALS
	|	SUM(CustomsValue)
	|BY
	|	Origin";
	
	Query.SetParameter("InvoicesArray", InvoicesArray);
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("Inventory", Inventory);
	Query.SetParameter("CommodityGroups", CommodityGroups);
	Query.SetParameter("DocumentCurrency", DocumentCurrency);
	Query.SetParameter("ExchangeRateMethod", DriveServer.GetExchangeMethod(Company));
	
	If IsNew() Then
		Query.SetParameter("RatesDate", CurrentSessionDate());
	Else
		Query.SetParameter("RatesDate", Date);
	EndIf;
	
	Results = Query.ExecuteBatch();
	
	SelHeader = Results[1].Select();
	While SelHeader.Next() Do
		
		If Not SelHeader.Posted Then
			Raise NStr("en = 'Please select a posted document.'; ru = 'Ввод на основании непроведенного документа запрещен.';pl = 'Wybierz zatwierdzony dokument.';es_ES = 'Por favor, seleccione un documento enviado.';es_CO = 'Por favor, seleccione un documento enviado.';tr = 'Lütfen, kaydedilmiş bir belge seçin.';it = 'Si prega di selezionare un documento pubblicato.';de = 'Bitte wählen Sie ein gebuchtes Dokument aus.'");
		EndIf;
		If Not SelHeader.VATTaxation = Enums.VATTaxationTypes.ForExport Then
			Raise NStr("en = 'Please select a document with ""Zero rate"" tax category.'; ru = 'Выберите документ с налоговой категорией ""Нулевая ставка"".';pl = 'Wybierz dokument z kategorią podatkową ""Zerowa stawka"".';es_ES = 'Por favor, seleccione un documento con el tipo del impuesto ""Tasa cero"".';es_CO = 'Por favor, seleccione un documento con el tipo del impuesto ""Tasa cero"".';tr = 'Lütfen ""Sıfır oranı"" vergi kategorisine sahip bir belge seçin.';it = 'Si prega di selezionare un documento con una categoria di imposta ""Aliquota zero"".';de = 'Bitte wählen Sie ein Dokument mit der Steuerkategorie ""Nullsatz"" aus.'");
		EndIf;
		
	EndDo;
	FillPropertyValues(ThisObject, SelHeader, , "Ref, Posted");
	
	SelCommodityGroups = Results[4].Select();
	If SelCommodityGroups.Next() Then
		MaxCommodityGruop = SelCommodityGroups.CommodityGroup;
	Else
		MaxCommodityGruop = 0;
	EndIf;
	
	SelOrigins = Results[7].Select(QueryResultIteration.ByGroups);
	While SelOrigins.Next() Do
		
		MaxCommodityGruop = MaxCommodityGruop + 1;
		
		NewCommodityGroupsRow = CommodityGroups.Add();
		NewCommodityGroupsRow.Origin = SelOrigins.Origin;
		NewCommodityGroupsRow.CustomsValue = SelOrigins.CustomsValue;
		NewCommodityGroupsRow.CommodityGroup = MaxCommodityGruop;
		
		SelInventory = SelOrigins.Select();
		
		While SelInventory.Next() Do
			
			If SelInventory.Quantity > 0 Then
			
				NewInventoryRow = Inventory.Add();
				FillPropertyValues(NewInventoryRow, SelInventory);
				NewInventoryRow.CommodityGroup = MaxCommodityGruop;
				
			EndIf;
			
		EndDo;
		
	EndDo;
	
	If GetFunctionalOption("UseDefaultTypeOfAccounting") Then
		GLAccountsInDocuments.FillGLAccountsInDocument(ThisObject, FillingData);
	EndIf;
	
EndProcedure

#EndRegion

Function InvoicesDataToBeChecked()
	
	Query = New Query;
	
	Query.Text =
	"SELECT
	|	Inventory.LineNumber AS LineNumber,
	|	Inventory.Invoice AS Invoice,
	|	Inventory.StructuralUnit AS StructuralUnit,
	|	Inventory.AdvanceInvoicing AS AdvanceInvoicing
	|INTO TT_Inventory
	|FROM
	|	&Inventory AS Inventory
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	TT_Inventory.LineNumber AS LineNumber,
	|	TT_Inventory.Invoice AS Invoice,
	|	TT_Inventory.StructuralUnit AS StructuralUnit,
	|	TT_Inventory.AdvanceInvoicing AS AdvanceInvoicing,
	|	SupplierInvoice.StructuralUnit AS InvoiceStructuralUnit,
	|	CASE
	|		WHEN SupplierInvoice.OperationKind = VALUE(Enum.OperationTypesSupplierInvoice.AdvanceInvoice)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS InvoiceAdvanceInvoicing,
	|	SupplierInvoice.Date AS InvoiceDate
	|INTO TT_InventoryWithData
	|FROM
	|	TT_Inventory AS TT_Inventory
	|		INNER JOIN Document.SupplierInvoice AS SupplierInvoice
	|		ON TT_Inventory.Invoice = SupplierInvoice.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_InventoryWithData.LineNumber AS LineNumber
	|FROM
	|	TT_InventoryWithData AS TT_InventoryWithData
	|WHERE
	|	TT_InventoryWithData.StructuralUnit <> TT_InventoryWithData.InvoiceStructuralUnit
	|	AND TT_InventoryWithData.StructuralUnit <> VALUE(Catalog.BusinessUnits.EmptyRef)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_InventoryWithData.LineNumber AS LineNumber
	|FROM
	|	TT_InventoryWithData AS TT_InventoryWithData
	|WHERE
	|	TT_InventoryWithData.AdvanceInvoicing <> TT_InventoryWithData.InvoiceAdvanceInvoicing
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MAX(TT_InventoryWithData.InvoiceDate) AS InvoiceDate
	|FROM
	|	TT_InventoryWithData AS TT_InventoryWithData
	|WHERE
	|	TT_InventoryWithData.InvoiceDate > &Date";
	
	Query.SetParameter("Inventory", Inventory);
	Query.SetParameter("Date", Date);
	
	QueryResults = Query.ExecuteBatch();
	
	Result = New Structure;
	Result.Insert("StructuralUnitsMatch", QueryResults[2].Unload());
	Result.Insert("AdvanceInvoicingMatch", QueryResults[3].Unload());
	Result.Insert("InvoicesDates", QueryResults[4].Unload());
	
	Return Result;
	
EndFunction

#EndRegion

#EndIf