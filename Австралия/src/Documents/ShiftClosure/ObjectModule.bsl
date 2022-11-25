#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

// Initializes document
//
Procedure InitializeDocument()
	
	CashCRSessionStart    = BegOfDay(CurrentSessionDate());
	CashCRSessionEnd = EndOfDay(CurrentSessionDate());
	
EndProcedure

// Fills the retail sale report according to filter.
//
// Parameters
//  FillingData - Structure with the filter values
//
Procedure FillDocumentByFilter(FillingData)
	
	If FillingData.Property("CashCR") Then
		FillDocumentByCachRegister(FillingData.CashCR);
	EndIf;
	
EndProcedure

// Fills the document tabular section according to the goods reconciliation at warehouse.
//
Procedure FillTabularSectionInventoryByGoodsInventoryAtWarehouse(FillingData)

	Stocktaking = FillingData.Ref;
	Company			= FillingData.Company;
	StructuralUnit	= FillingData.StructuralUnit;
	Cell			= FillingData.Cell;
	
	VATTaxation = DriveServer.VATTaxation(Company, Date);
	
	Query = New Query(
	"SELECT ALLOWED
	|	MIN(Stocktaking.LineNumber) AS LineNumber,
	|	Stocktaking.Products AS Products,
	|	Stocktaking.Characteristic AS Characteristic,
	|	Stocktaking.Batch AS Batch,
	|	Stocktaking.MeasurementUnit AS MeasurementUnit,
	|	MAX(Stocktaking.QuantityAccounting - Stocktaking.Quantity) AS QuantityInventorytakingRejection,
	|	SUM(CASE
	|			WHEN ShiftClosure.Quantity IS NULL
	|				THEN 0
	|			ELSE ShiftClosure.Quantity
	|		END) AS QuantityDebited,
	|	Stocktaking.Price AS Price,
	|	Stocktaking.Products.VATRate AS VATRate,
	|	Stocktaking.ConnectionKey
	|FROM
	|	Document.Stocktaking.Inventory AS Stocktaking
	|		LEFT JOIN Document.ShiftClosure.Inventory AS ShiftClosure
	|		ON Stocktaking.Products = ShiftClosure.Products
	|			AND Stocktaking.Characteristic = ShiftClosure.Characteristic
	|			AND Stocktaking.Batch = ShiftClosure.Batch
	|			AND Stocktaking.Ref = ShiftClosure.Ref.Stocktaking
	|			AND (ShiftClosure.Ref <> &DocumentRef)
	|			AND (ShiftClosure.Ref.Posted)
	|WHERE
	|	Stocktaking.Ref = &BasisDocument
	|	AND Stocktaking.QuantityAccounting - Stocktaking.Quantity > 0
	|
	|GROUP BY
	|	Stocktaking.Products,
	|	Stocktaking.Characteristic,
	|	Stocktaking.Batch,
	|	Stocktaking.MeasurementUnit,
	|	Stocktaking.Price,
	|	Stocktaking.Products.VATRate,
	|	Stocktaking.ConnectionKey
	|
	|ORDER BY
	|	LineNumber");
		
	Query.SetParameter("BasisDocument", FillingData.Ref);
	Query.SetParameter("DocumentRef", Ref);
		
	QueryResult = Query.Execute();
		
	If Not QueryResult.IsEmpty() Then
		
		Selection = QueryResult.Select();
			
		// Filling document tabular section.
		Inventory.Clear();
		
		While Selection.Next() Do
			
			QuantityToReceive = Selection.QuantityInventorytakingRejection - Selection.QuantityDebited;
			If QuantityToReceive <= 0 Then
				Continue;
			EndIf;
			
			TabularSectionRow = Inventory.Add();
			FillPropertyValues(TabularSectionRow, Selection);
			TabularSectionRow.Quantity = QuantityToReceive;
			TabularSectionRow.Amount   = TabularSectionRow.Quantity * TabularSectionRow.Price;
			
			If VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
				
				TabularSectionRow.VATRate = Selection.VATRate;
				VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.VATRate);
				TabularSectionRow.VATAmount = ?(AmountIncludesVAT,
												TabularSectionRow.Amount
												- (TabularSectionRow.Amount) / ((VATRate + 100) / 100),
												TabularSectionRow.Amount * VATRate / 100);
			
				TabularSectionRow.Total = TabularSectionRow.Amount + ?(AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
				
			Else
				If VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT Then	
				
					DefaultVATRate = Catalogs.VATRates.Exempt;
				
				Else
				
					DefaultVATRate = Catalogs.VATRates.ZeroRate;
				
				EndIf;
				
				TabularSectionRow.VATRate = DefaultVATRate;
				TabularSectionRow.VATAmount = 0;
			
				TabularSectionRow.Total = TabularSectionRow.Amount;
				
			EndIf;
			
		EndDo;
		
	EndIf;
		
	If Inventory.Count() = 0 Then
		
		Message = New UserMessage();
		Message.Text = NStr("en = 'No data to fill in by physical inventory.'; ru = 'Нет данных для заполнения по инвентаризации!';pl = 'Brak danych do wypełnienia według inwentaryzacji.';es_ES = 'No hay datos para rellenar en el inventario físico.';es_CO = 'No hay datos para rellenar en el inventario físico.';tr = 'Fiziksel stok göre doldurulacak veri yok.';it = 'Non ci sono dati da compilare per inventario fisico.';de = 'Es gibt keine Daten zum Ausfüllen der physischen Inventur.'");
		Message.Message();
		
		StandardProcessing = False;
		
	EndIf;
	
EndProcedure

// Fills document by CR petty cash 
//
Procedure FillDocumentByCachRegister(CashCR)
	
	CashRegisterAttributes = Catalogs.CashRegisters.GetCashRegisterAttributes(CashCR);
	FillPropertyValues(ThisObject, CashRegisterAttributes);
	VATTaxation = DriveServer.VATTaxation(Company, Date);
	
EndProcedure

// Fills document by warehouse cash register if there is only one cash register at the warehouse.
//
Procedure FillDocumentByWarehouse(StructuralUnit)
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED TOP 2
	|	CashRegisters.Ref AS CashCR
	|FROM
	|	Catalog.CashRegisters AS CashRegisters
	|WHERE
	|	CashRegisters.StructuralUnit = &StructuralUnit";
	
	Query.SetParameter("StructuralUnit", StructuralUnit);
	
	Selection = Query.Execute().Select();
	If Selection.Count() = 1
	   AND Selection.Next()
	Then
		CashCR = Selection.CashCR;
		FillDocumentByCachRegister(CashCR);
	EndIf;
	
EndProcedure

// Fills the retail sales report according to the goods reconciliation at warehouse.
//
// Parameters
//  FillingData - Structure with the filter values
//
Procedure FillByInventoryInventoryAtWarehouse(FillingData)
	
	StructuralUnit            = FillingData.StructuralUnit;
	ProductsAtWarehouseReconciliation = FillingData.Ref;
	
	FillDocumentByWarehouse(StructuralUnit);
	
	FillTabularSectionInventoryByGoodsInventoryAtWarehouse(FillingData);
	
EndProcedure

// Adds additional attributes necessary for document
// posting to passed structure.
//
// Parameters:
//  StructureAdditionalProperties - Structure of additional document properties.
//
Procedure AddAttributesToAdditionalPropertiesForPosting(StructureAdditionalProperties) Export
	
	If CashCR.CashCRType = Enums.CashRegisterTypes.FiscalRegister Then
		CompletePosting = CashCRSessionStatus = Enums.ShiftClosureStatus.ClosedReceiptsArchived;
	Else
		CompletePosting = (CashCRSessionStatus = Enums.ShiftClosureStatus.ClosedReceiptsArchived)
					   OR (CashCRSessionStatus = Enums.ShiftClosureStatus.Closed);
	EndIf;
	
	StructureAdditionalProperties.ForPosting.Insert("CompletePosting", CompletePosting);
	
EndProcedure

#EndRegion

#Region EventHandlers

// Procedure - handler of the FillingProcessor event.
//
Procedure Filling(FillingData, FillingText, StandardProcessing)
	
	DataTypeFill = TypeOf(FillingData);
	
	If DataTypeFill = Type("Structure") Then
		
		FillDocumentByFilter(FillingData);
		
	ElsIf DataTypeFill = Type("DocumentRef.Stocktaking") Then
		
		If FillingData.StructuralUnit.StructuralUnitType <> Enums.BusinessUnitsTypes.Retail Then
			Raise(NStr("en = 'Please select a POS with CMA type.'; ru = 'Укажите POS c типом CMA.';pl = 'Wybierz zamówienie zakupu z typem CMA.';es_ES = 'Por favor, seleccione un TPV con el tipo de contable de gestión empresarial certificado.';es_CO = 'Por favor, seleccione un TPV con el tipo de contable de gestión empresarial certificado.';tr = 'Lütfen CMA tipinde bir POS seçin';it = 'Per piacere selezionare un Punto Vendita con tipo CMA.';de = 'Bitte wählen Sie ein POS mit dem Typ der Bewertung zum Einstandspreis.'"));
		Else
			FillByInventoryInventoryAtWarehouse(FillingData);
		EndIf;
		
	Else
		
		CashCR = Catalogs.CashRegisters.GetCashCRByDefault();
		If CashCR <> Undefined Then
			FillDocumentByCachRegister(CashCR);
		EndIf;
		
	EndIf;
	
	InitializeDocument();
	
	WorkWithVAT.ForbidReverseChargeTaxationTypeDocumentGeneration(ThisObject);
	
EndProcedure

// Procedure - event handler BeforeWrite object.
//
Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If PositionResponsible = Enums.AttributeStationing.InHeader Then
		For Each TabularSectionRow In Inventory Do
			TabularSectionRow.Responsible = Responsible;
		EndDo;
	EndIf;
	
	DocumentAmount = Inventory.Total("Total");
	
	// Change of approved documents
	AccountingApprovalServer.BeforeWriteAtServer(ThisObject, Cancel);
	// End Change of approved documents
	
	AdditionalProperties.Insert("WriteMode", WriteMode);
	AdditionalProperties.Insert("Posted", Posted);
	
	InventoryOwnershipServer.FillOwnershipTable(ThisObject, WriteMode, Cancel);
	
EndProcedure

// Procedure - FillCheckProcessing event handler.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	CashCRType = Catalogs.CashRegisters.GetCashRegisterAttributes(CashCR).CashCRType;
	
	If PaymentWithPaymentCards.Total("Amount") > DocumentAmount Then
		
		ErrorText = NStr("en = 'Card payment amount is greater than the document amount'; ru = 'Сумма оплаты по карте превышает сумму документа';pl = 'Suma opłaty płatniczymi kartami przekracza sumę dokumentu';es_ES = 'Importe del pago con tarjeta es mayor al importe del documento';es_CO = 'Importe del pago con tarjeta es mayor al importe del documento';tr = 'Kart ödeme tutarı, belge tutarından daha büyüktür';it = 'L''importo del pagamento con carta è superiore all''importo del documento';de = 'Kartenzahlungsbetrag ist größer als der Belegbetrag'");
		
		DriveServer.ShowMessageAboutError(
			ThisObject,
			ErrorText,
			Undefined,
			Undefined,
			"PaymentWithPaymentCards",
			Cancel
		);
		
	EndIf;
	
	If CashCRType = Enums.CashRegisterTypes.FiscalRegister Then
		
		OpenedCashCRSession = Documents.ShiftClosure.GetOpenCashCRSession(CashCR, Ref, CashCRSessionStart, CashCRSessionEnd);
		If OpenedCashCRSession <> Undefined
			AND OpenedCashCRSession <> Ref Then
			
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
							NStr("en = '%2 is already registered for this cash register on date %1.'; ru = 'По данной кассе на дату %1 уже зарегистрирован %2';pl = '%2 jest już zarejestrowany na tę kasę fiskalną w terminie %1.';es_ES = '%2 ya se ha registrado para esta caja registradora en la fecha %1.';es_CO = '%2 ya se ha registrado para esta caja registradora en la fecha %1.';tr = 'Bu kasa için %2 %1 tarihi itibariyle zaten kayıtlıdır.';it = '%2 è già stato registrato per questo registratore di cassa in data %1';de = '%2 ist bereits am Datum %1 für diese Kasse registriert.'"),
							Date,
							OpenedCashCRSession);
			
			DriveServer.ShowMessageAboutError(
				ThisObject,
				ErrorText,
				Undefined,
				Undefined,
				"",
				Cancel);
			
		EndIf;
		
		If Not ValueIsFilled(CashCRSessionEnd)
			 AND ValueIsFilled(CashCRSessionStatus)
			 AND CashCRSessionStatus <> Enums.ShiftClosureStatus.IsOpen Then
			
			ErrorText = NStr("en = 'The ""Shift end"" field is not filled in'; ru = 'Поле ""Окончание смены"" не заполнено';pl = 'Nie wypełniono pola ""Zakończenie zmiany""';es_ES = 'El campo ""Fin del turno"" no está rellenado';es_CO = 'El campo ""Fin del turno"" no está rellenado';tr = '""Vardiya sonu"" alanı doldurulmadı';it = 'Il campo ""Fine turno"" non è compilato';de = 'Das Feld ""Schichtende"" ist nicht ausgefüllt'");
			
			DriveServer.ShowMessageAboutError(
				ThisObject,
				ErrorText,
				Undefined,
				Undefined,
				"CashCRSessionEnd",
				Cancel
			);
			
		EndIf;
		
		If ValueIsFilled(CashCRSessionEnd)
			 AND CashCRSessionEnd < CashCRSessionStart Then
			
			ErrorText = NStr("en = 'Start time of the register shift is later than the end time of the register shift'; ru = 'Время начала кассовой смены больше времени окончания кассовой смены';pl = 'Godzina rozpoczęcia zmiany jest późniejsza niż godzina zakończenia zmiany';es_ES = 'Hora del inicio del turno del registro es posterior a la hora del fin del turno del registro';es_CO = 'Hora del inicio del turno del registro es posterior a la hora del fin del turno del registro';tr = 'Kasa vardiyasının başlama zamanı, kasa vardiyasının bitiş zamanından daha sonraki bir zaman dilimi olarak girilmiş';it = 'L''orario di inizio del turno di cassa è successivo all''orario di fine del turno di cassa';de = 'Die Startzeit der Kassenschicht ist später als die Endzeit der Kassenschicht'");
			
			DriveServer.ShowMessageAboutError(
				ThisObject,
				ErrorText,
				Undefined,
				Undefined,
				"CashCRSessionEnd",
				Cancel
			);
			
		EndIf;
		
		
		If ValueIsFilled(CashCRSessionStatus)
			 AND CashCRSessionStatus = Enums.ShiftClosureStatus.IsOpen
			 AND CashCRSessionStart <> Date Then
			
			ErrorText = NStr("en = 'Start time of the register shift is different from the document date'; ru = 'Время начала кассовой смены отличается от даты документа';pl = 'Czas rozpoczęcia zmiany różni się od daty dokumentu';es_ES = 'Hora del inicio del turno del registro es diferente de la fecha del documento';es_CO = 'Hora del inicio del turno del registro es diferente de la fecha del documento';tr = 'Kasa vardiyasının başlangıç zamanı, belge tarihinden farklıdır';it = 'L''orario di inizio del turno di cassa è differente da quello della data del documento';de = 'Die Startzeit der Kassenschicht unterscheidet sich vom Belegdatum'");
			
			DriveServer.ShowMessageAboutError(
				ThisObject,
				ErrorText,
				Undefined,
				Undefined,
				"CashCRSessionStart",
				Cancel
			); 
			
		EndIf;
		
		If ValueIsFilled(CashCRSessionStatus)
			 AND CashCRSessionStatus <> Enums.ShiftClosureStatus.IsOpen
			 AND CashCRSessionEnd <> Date Then
			
			ErrorText = NStr("en = 'End time of the register shift is different from the document date'; ru = 'Время окончания кассовой смены отличается от даты документа';pl = 'Czas zakończenia zmiany różni się od daty dokumentu';es_ES = 'Hora del fin del turno del registro es diferente de la fecha del documento';es_CO = 'Hora del fin del turno del registro es diferente de la fecha del documento';tr = 'Kasa vardiyasının bitiş zamanı, belge tarihinden farklıdır';it = 'L''orario di fine del turno di cassa è differente dalla data del documento';de = 'Die Endzeit der Kassenschicht unterscheidet sich vom Belegdatum'");
			
			DriveServer.ShowMessageAboutError(
				ThisObject,
				ErrorText,
				Undefined,
				Undefined,
				"CashCRSessionEnd",
				Cancel
			);
			
		EndIf;
	
	EndIf;
	
	// 100% discount.
	If Constants.UseManualDiscounts.Get() Then
		For Each StringInventory In Inventory Do
			If StringInventory.DiscountMarkupPercent <> 100 
				AND Not ValueIsFilled(StringInventory.Amount) Then
				MessageText = NStr("en = 'The ""Amount"" column is not populated in the %Number% line of the ""Inventory"" list.'; ru = 'Не заполнена колонка ""Сумма"" в строке %Number% списка ""Запасы"".';pl = 'Nie wypełniono kolumny ""Kwota"" w wierszu %Number% listy ""Zapasy"".';es_ES = 'La columna ""Importe"" no está poblada en la línea %Number% de la lista ""Inventario"".';es_CO = 'La columna ""Importe"" no está poblada en la línea %Number% de la lista ""Inventario"".';tr = '""Tutar"" sütunu, ""Stok"" listesinin %Number% satırında gösterilmez.';it = 'La colonna ""Importo"" non è compilata nella linea %Number% dell''elenco ""Scorte"".';de = 'Die Spalte ""Betrag"" ist nicht in der %Number% Zeile der Liste ""Bestand"" eingetragen.'");
				MessageText = StrReplace(MessageText, "%Number%", StringInventory.LineNumber);
				DriveServer.ShowMessageAboutError(
					ThisObject,
					MessageText,
					"Inventory",
					StringInventory.LineNumber,
					"Amount",
					Cancel
				);
			EndIf;
		EndDo;
	EndIf;
	
	If Not WorkWithVATServerCall.CompanyIsRegisteredForVAT(Company, Date) Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "CompanyVATNumber");
	EndIf;
	
	// Serial numbers
	WorkWithSerialNumbers.FillCheckingSerialNumbers(Cancel, Inventory, SerialNumbers, StructuralUnit, ThisObject);
	
	BatchesServer.CheckFilling(ThisObject, Cancel);
	
EndProcedure

// Procedure - event handler Posting().
//
Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting.
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Accounting templates properties initialization.
	AccountingTemplatesPosting.InitializeAccountingTemplatesProperties(Ref, AdditionalProperties, Cancel);
	If AdditionalProperties.ForPosting.AccountingTemplatesPostingUnavailable Then
		Return;
	EndIf;
	
	AddAttributesToAdditionalPropertiesForPosting(AdditionalProperties);
	
	// Document data initialization.
	Documents.ShiftClosure.InitializeDocumentData(Ref, AdditionalProperties);
	
	AccountingTemplatesPosting.CheckEntriesAccounts(AdditionalProperties, Cancel);
	
	// Preparation of records sets.
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Account for in accounting sections.
	DriveServer.ReflectInventory(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectSales(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectInventoryInWarehouses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpenses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpensesCashMethod(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectCashAssetsInCashRegisters(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectInventoryAccepted(AdditionalProperties, RegisterRecords, Cancel);
	
	// DiscountCards
	DriveServer.ReflectSalesByDiscountCard(AdditionalProperties, RegisterRecords, Cancel);
	
	// SerialNumbers
	DriveServer.ReflectTheSerialNumbersOfTheGuarantee(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectTheSerialNumbersBalance(AdditionalProperties, RegisterRecords, Cancel);
	
	// AutomaticDiscounts
	DriveServer.FlipAutomaticDiscountsApplied(AdditionalProperties, RegisterRecords, Cancel);
	
	// Accounting
	DriveServer.ReflectAccountingJournalEntries(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntriesSimple(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntriesCompound(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingEntriesData(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectDocumentAccountingEntriesStatuses(ThisObject, AdditionalProperties, RegisterRecords, Cancel);
	
	DriveServer.ReflectVATOutput(AdditionalProperties, RegisterRecords, Cancel);
	
	// Record of the records sets.
	DriveServer.WriteRecordSets(ThisObject);
	
	// Control of occurrence of a negative balance.
	Documents.ShiftClosure.RunControl(Ref, AdditionalProperties, Cancel);
	
	DriveServer.CreateRecordsInTasksRegisters(ThisObject, Cancel);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
	AccountingTemplatesPosting.CheckForDuplicateAccountingEntries(Ref, Company, Date, Cancel);
	
	// Subordinate documents
	If Not Cancel Then
		
		AccountingTemplatesPosting.CreateRefreshTransactionDocumentsByMode(
			Ref, DocumentWriteMode.Posting, DeletionMark, Company, Date, AdditionalProperties);
		
	EndIf;
		
EndProcedure

// Procedure - handler of event PostingDeletionDataProcessor.
//
Procedure UndoPosting(Cancel)
	
	// Initialization of additional properties for document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);
	
	// Control of occurrence of a negative balance.
	Documents.ShiftClosure.RunControl(Ref, AdditionalProperties, Cancel, True);
	
	DriveServer.CreateRecordsInTasksRegisters(ThisObject, Cancel);
	
	AccountingTemplatesPosting.CheckForDuplicateAccountingEntries(Ref, Company, Date, Cancel);
	
	// Subordinate documents
	If Not Cancel Then
		
		AccountingTemplatesPosting.CreateRefreshTransactionDocumentsByMode(
			Ref, DocumentWriteMode.UndoPosting, DeletionMark, Company, Date, AdditionalProperties);
			
		DriveServer.ReflectDeletionAccountingTransactionDocuments(Ref);
		
	EndIf;
		
EndProcedure

Procedure OnCopy(CopiedObject)
	
	If SerialNumbers.Count() Then
		
		For Each InventoryLine In Inventory Do
			InventoryLine.SerialNumbers = "";
		EndDo;
		
		SerialNumbers.Clear();
		
	EndIf;
	
	InventoryOwnership.Clear();
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	DriveServer.CheckDocumentsReposting(Ref, AdditionalProperties.Posted, Cancel);
	
	If Not Cancel And AdditionalProperties.WriteMode = DocumentWriteMode.Write Then
		
		AccountingTemplatesPosting.CreateRefreshTransactionDocumentsByMode(
			Ref, AdditionalProperties.WriteMode, DeletionMark, Company, Date, AdditionalProperties);
		
	EndIf;
		
EndProcedure

#EndRegion

#EndIf
