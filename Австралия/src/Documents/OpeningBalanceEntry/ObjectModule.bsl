#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions
// Procedure of the document filling based on the sales invoice.
//
// Parameters:
// BasisDocument - DocumentRef.SalesInvoice - sales invoice 
// FillingData - Structure - Document filling data
//	
Procedure FillByStocktaking(FillingData)
	
	// Filling out a document header.
	BasisDocument = FillingData.Ref;
	Company = FillingData.Company;
	AccountingSection = Enums.OpeningBalanceAccountingSections.Inventory;
	
	// Filling document tabular section.
	For Each TabularSectionRow In FillingData.Inventory Do
		
		If TabularSectionRow.Quantity > 0 Then
			OwnershipType = Common.ObjectAttributeValue(TabularSectionRow.Ownership, "OwnershipType");
			If OwnershipType = Enums.InventoryOwnershipTypes.OwnInventory Then
				NewRow = Inventory.Add();
				FillPropertyValues(NewRow, TabularSectionRow);
				NewRow.StructuralUnit = FillingData.StructuralUnit;
				NewRow.Cell = FillingData.Cell;
			EndIf;
		EndIf;
		
	EndDo;
	
	If GetFunctionalOption("UseDefaultTypeOfAccounting") Then
		GLAccountsInDocuments.FillGLAccountsInDocument(ThisObject, FillingData);
	EndIf;

EndProcedure

Function GenerateDocument(TSRow, ARAP = True)
	
	DocMetadata = TSRow.Document.Metadata();
	
	NewDoc = Documents[DocMetadata.Name].CreateDocument();
	NewDoc.Number = TSRow.DocumentNumber;
	NewDoc.Date = TSRow.DocumentDate;
	NewDoc.ForOpeningBalancesOnly = True;
	
	SetDocAttributeOperationKind(DocMetadata.Name, NewDoc);
	
	If Common.HasObjectAttribute("Company", DocMetadata) Then
		NewDoc.Company = Company;
	EndIf;
	
	If Common.HasObjectAttribute("StructuralUnit", DocMetadata)
		And CommonClientServer.HasAttributeOrObjectProperty(TSRow, "StructuralUnit") Then
		
		NewDoc.StructuralUnit = TSRow.StructuralUnit;
	EndIf;
	
	If Common.HasObjectAttribute("Cell", DocMetadata)
		And CommonClientServer.HasAttributeOrObjectProperty(TSRow, "Cell") Then
		
		NewDoc.Cell = TSRow.Cell;
	EndIf;
	
	If Common.HasObjectAttribute("DocumentAmount", DocMetadata)
		And CommonClientServer.HasAttributeOrObjectProperty(TSRow, "AmountCur") Then
		
		NewDoc.DocumentAmount = TSRow.AmountCur;
	EndIf;
	
	If Common.HasObjectAttribute("Comment", DocMetadata) Then
		NewDoc.Comment = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Generated automatically by the ""Opening balance entry"" document %1 dated %2'; ru = 'Создано автоматически на основании документа ""Ввод начальных остатков"" %1 от %2';pl = 'Wygenerowano automatycznie przez dokument ""Wprowadzenie salda początkowego"" %1 z dn. %2';es_ES = 'Generado automáticamente por el documento ""Entrada de saldo inicial"" %1fechado %2';es_CO = 'Generado automáticamente por el documento ""Entrada de saldo inicial"" %1fechado %2';tr = '%2 tarihli %1 ""Açılış bakiyesi girişi"" belgesiyle otomatik olarak oluşturuldu';it = 'Generato automaticamente da ""Inserimento di saldo iniziale"" %1 datato %2';de = 'Mit ""Buchung des Anfangssaldos""-Dokument %1 vom %2% automatisch generiert'"),
			Number,
			Format(Date, "DLF=D"));
	EndIf;
	
	If Common.HasObjectAttribute("Author", DocMetadata) Then
		NewDoc.Author = Users.CurrentUser();
	EndIf;
	
	If ARAP Then
		
		If Common.HasObjectAttribute("Counterparty", DocMetadata)
			And CommonClientServer.HasAttributeOrObjectProperty(TSRow, "Counterparty") Then
			
			NewDoc.Counterparty = TSRow.Counterparty;
		EndIf;
		If Common.HasObjectAttribute("Contract", DocMetadata)
			And CommonClientServer.HasAttributeOrObjectProperty(TSRow, "Contract") Then
			
			NewDoc.Contract = TSRow.Contract;
		EndIf;
		If Common.HasObjectAttribute("OrderState", DocMetadata) Then
			NewDoc.OrderState = Constants.StateCompletedSalesOrders.Get();
			If Common.HasObjectAttribute("OperationKind", DocMetadata) Then
				NewDoc.OperationKind = Enums.OperationTypesSalesOrder.OrderForSale;
			EndIf;
		EndIf;
		
		If CommonClientServer.HasAttributeOrObjectProperty(TSRow, "Contract") Then
			TSRowCurrency = Common.ObjectAttributeValue(TSRow.Contract, "SettlementsCurrency");
		Else
			TSRowCurrency = Company.PresentationCurrency;
		EndIf;
		
	Else
		
		If Common.HasObjectAttribute("Employee", DocMetadata) Then		
			NewDoc.Employee = TSRow.Employee;
		EndIf;
		If Common.HasObjectAttribute("AdvanceHolder", DocMetadata) Then			
			NewDoc.AdvanceHolder = TSRow.Employee;
		EndIf;
		
		TSRowCurrency = TSRow.Currency;
		
	EndIf;
	
	If Common.HasObjectAttribute("DocumentCurrency", DocMetadata) Then
		NewDoc.DocumentCurrency = TSRowCurrency;
	EndIf;
	If Common.HasObjectAttribute("CashCurrency", DocMetadata) Then
		NewDoc.CashCurrency = TSRowCurrency;
	EndIf;
	
	If Common.HasObjectAttribute("ExchangeRate", DocMetadata) Then
		NewDoc.ExchangeRate = 1;
	EndIf;
	If Common.HasObjectAttribute("Multiplicity", DocMetadata) Then
		NewDoc.Multiplicity = 1;
	EndIf;
	If Common.HasObjectAttribute("ContractCurrencyExchangeRate", DocMetadata) Then
		NewDoc.ContractCurrencyExchangeRate = 1;
	EndIf;
	If Common.HasObjectAttribute("ContractCurrencyMultiplicity", DocMetadata) Then
		NewDoc.ContractCurrencyMultiplicity = 1;
	EndIf;
	
	NewDoc.DataExchange.Load = True;
	NewDoc.Posted = True;
	NewDoc.Write();
	
	Return NewDoc.Ref;
	
EndFunction

Procedure FillInventoryAcquisitionDocuments()
	
	If AccountingSection <> Enums.OpeningBalanceAccountingSections.Inventory Then
		Return;
	EndIf;
	
	If AutogenerateInventoryAcqusitionDocuments Then
		
		GroupedInventoryTable = Inventory.Unload(, "StructuralUnit,DocumentNumber,DocumentDate,Document");
		GroupedInventoryTable.GroupBy("StructuralUnit,DocumentNumber,DocumentDate,Document");
		
		For Each GroupedInventoryTableRow In GroupedInventoryTable Do			
			If ValueIsFilled(GroupedInventoryTableRow.Document)
				Or GroupedInventoryTableRow.Document = Undefined Then
				
				Continue;
			EndIf;
			
			Filter = Common.ValueTableRowToStructure(GroupedInventoryTableRow);
			InventoryRows = Inventory.FindRows(Filter);	
			NewDocRef = GenerateDocument(InventoryRows[0]);
			For Each InventoryRow In InventoryRows Do
				InventoryRow.Document = NewDocRef;
			EndDo;			
		EndDo;
		
	EndIf;
	
	ObjectRef = Ref;
	
	If IsNew() Then
		
		ObjectRef = GetNewObjectRef();
		If ObjectRef.IsEmpty() Then
			
			ObjectRef = Documents.OpeningBalanceEntry.GetRef();
			SetNewObjectRef(ObjectRef);
			
		EndIf;
		
	EndIf;
	
	For Each InventoryRow In Inventory Do
		
		If ValueIsFilled(InventoryRow.Document) Then
			Continue;
		EndIf;
		
		InventoryRow.Document = ObjectRef;
		
	EndDo;
	
EndProcedure

Procedure SetDocAttributeOperationKind(StringDocName, NewDoc)
	
	If Not (StringDocName = "SupplierInvoice" 
		Or StringDocName = "PaymentExpense"
		Or StringDocName = "CashVoucher"
		Or StringDocName = "CreditNote"
		Or StringDocName = "DebitNote"
		Or StringDocName = "ArApAdjustments"
		Or StringDocName = "AdditionalExpenses"
		Or StringDocName = "SalesInvoice"
		Or StringDocName = "PaymentReceipt" 
		Or StringDocName = "CashReceipt") Then
		
		Return;
		
	ElsIf StringDocName = "SupplierInvoice" Then
		
		NewDoc.OperationKind = Enums.OperationTypesSupplierInvoice.Invoice;
		
	ElsIf StringDocName = "PaymentExpense" Then
		
		NewDoc.OperationKind = Enums.OperationTypesPaymentExpense.Vendor;
		
	ElsIf StringDocName = "CashVoucher" Then
		
		NewDoc.OperationKind = Enums.OperationTypesCashVoucher.Vendor;
		
	ElsIf StringDocName = "CreditNote" Then
		
		NewDoc.OperationKind = Enums.OperationTypesCreditNote.DiscountAllowed;
		
	ElsIf StringDocName = "DebitNote" Then
		
		NewDoc.OperationKind = Enums.OperationTypesDebitNote.DiscountReceived;
		
	ElsIf StringDocName = "ArApAdjustments" Then
		
		NewDoc.OperationKind = Enums.OperationTypesArApAdjustments.ArApAdjustments;
		
	ElsIf StringDocName = "AdditionalExpenses" Then
		
		NewDoc.OperationKind = Enums.OperationTypesAdditionalExpenses.LandedCosts;
		
	ElsIf StringDocName = "SalesInvoice" Then
		
		NewDoc.OperationKind = Enums.OperationTypesSalesInvoice.Invoice;
		
	ElsIf StringDocName = "PaymentReceipt" Then
		
		NewDoc.OperationKind = Enums.OperationTypesPaymentReceipt.FromCustomer;
		
	ElsIf StringDocName = "CashReceipt" Then
		
		NewDoc.OperationKind = Enums.OperationTypesCashReceipt.FromCustomer;
		
	EndIf;
	
EndProcedure

Procedure CheckCashAssetsFilling(Cancel, CheckedAttributes)
	
	DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "CashAssets.BankAccountPettyCash");
	DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "CashAssets.CashCurrency");
	DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "CashAssets.AmountCur");
	DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "CashAssets.Amount");
	
	LineNumbers = New Structure("CashAssetsBank, CashAssetsCash", 0, 0);
	
	AccountNames = New Structure;
	AccountNames.Insert("CashAssetsBank", NStr("en = 'Bank account'; ru = 'Банковский счет';pl = 'Rachunek bankowy';es_ES = 'Cuenta bancaria';es_CO = 'Cuenta bancaria';tr = 'Banka hesabı';it = 'Conto corrente';de = 'Bankkonto'"));
	AccountNames.Insert("CashAssetsCash", NStr("en = 'Cash account'; ru = 'Кассовый счет';pl = 'Kasa';es_ES = 'Cuenta de efectivo';es_CO = 'Cuenta de efectivo';tr = 'Kasa hesabı';it = 'Conto di cassa';de = 'Liquiditätskonto'"));
	
	TabNames = New Structure;
	TabNames.Insert("CashAssetsBank", NStr("en = 'Bank'; ru = 'Банк';pl = 'Bank';es_ES = 'Banco';es_CO = 'Banco';tr = 'Banka';it = 'Banca';de = 'Bank'"));
	TabNames.Insert("CashAssetsCash", NStr("en = 'Cash'; ru = 'Наличные';pl = 'Środki pieniężne';es_ES = 'En efectivo';es_CO = 'En efectivo';tr = 'Nakit';it = 'Contante';de = 'Liquidität'"));
	
	AmountPCTitle = "";
	
	OverdraftInfoTable = GetBankAccountsOverdraftInfo();
	OverdraftRow = New Structure("UseOverdraft, Limit", False, 0);
	
	For Each Row In CashAssets Do
		
		If TypeOf(Row.BankAccountPettyCash) = Type("CatalogRef.CashAccounts") Then
			TableName = "CashAssetsCash";
		Else
			TableName = "CashAssetsBank";
		EndIf;
		
		LineNumbers[TableName] = LineNumbers[TableName] + 1;
		
		MessageTemplate = NStr("en = 'The ""%1"" is required on line %2 of the ""%3"" list.'; ru = 'В строке %2 списка ""%3"" необходимо указать ""%1"".';pl = '""%1"" jest wymagany w wierszu %2 listy ""%3"".';es_ES = 'El ""%1"" se requiere en la línea %2 de la lista ""%3"".';es_CO = 'El ""%1"" se requiere en la línea %2 de la lista ""%3"".';tr = '""%3"" listesinin %2 satırında ""%1"" gerekli.';it = '""%1"" è richiesto nella riga %2 dell''elenco ""%3"".';de = '""%1"" ist in der Zeile %2 der ""%3"" Liste erforderlich.'");
		
		If Not ValueIsFilled(Row.BankAccountPettyCash) Then
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageTemplate,
				AccountNames[TableName], LineNumbers[TableName], TabNames[TableName]);
			MessageField = CommonClientServer.PathToTabularSection("", LineNumbers[TableName], "BankAccountPettyCash");
			CommonClientServer.MessageToUser(MessageText, ThisObject, MessageField, TableName, Cancel);
		EndIf;
		If Not ValueIsFilled(Row.CashCurrency) Then
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageTemplate,
				NStr("en = 'Currency'; ru = 'Валюта';pl = 'Waluta';es_ES = 'Moneda';es_CO = 'Moneda';tr = 'Para birimi';it = 'Valuta';de = 'Währung'"), LineNumbers[TableName], TabNames[TableName]);
			MessageField = CommonClientServer.PathToTabularSection("", LineNumbers[TableName], "CashCurrency");
			CommonClientServer.MessageToUser(MessageText, ThisObject, MessageField, TableName, Cancel);
		EndIf;
		If Not ValueIsFilled(Row.AmountCur) Then
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageTemplate,
				NStr("en = 'Amount'; ru = 'Сумма';pl = 'Wartość';es_ES = 'Importe';es_CO = 'Importe';tr = 'Tutar';it = 'Importo';de = 'Betrag'"), LineNumbers[TableName], TabNames[TableName]);
			MessageField = CommonClientServer.PathToTabularSection("", LineNumbers[TableName], "AmountCur");
			CommonClientServer.MessageToUser(MessageText, ThisObject, MessageField, TableName, Cancel);
		EndIf;
		If Not ValueIsFilled(Row.Amount) Then
			If IsBlankString(AmountPCTitle) Then
				PresentationCurrency = DriveServer.GetPresentationCurrency(Company);
				AmountPCTitle = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Amount (%1)'; ru = 'Сумма (%1)';pl = 'Wartość (%1)';es_ES = 'Importe (%1)';es_CO = 'Importe (%1)';tr = 'Tutar (%1)';it = 'Importo (%1)';de = 'Betrag (%1)'"),
					PresentationCurrency);
			EndIf;
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageTemplate,
				AmountPCTitle, LineNumbers[TableName], TabNames[TableName]);
			MessageField = CommonClientServer.PathToTabularSection("", LineNumbers[TableName], "Amount");
			CommonClientServer.MessageToUser(MessageText, ThisObject, MessageField, TableName, Cancel);
		EndIf;
		If ValueIsFilled(Row.AmountCur) And ValueIsFilled(Row.Amount) Then
			If (Row.AmountCur > 0 And Row.Amount < 0) Or (Row.AmountCur < 0 And Row.Amount > 0) Then
				Text = NStr("en = 'Cannot post the document. On the ""%1"" tab, in line #%2, ""Amount"" and ""Amount in currency"" must be numbers of the same type: positive or negative.'; ru = 'Не удалось провести документ. На вкладке ""%1"" в строке №%2 ""Сумма"" и ""Сумма (вал.)"" должны быть числами одного типа: положительными или отрицательными.';pl = 'Nie można zatwierdzić dokumentu. Na karcie ""%1"", w wierszu nr %2, ""Kwota"" i ""Kwota w walucie"" powinny być liczbami tego samego typu: dodatnimi lub ujemnymi.';es_ES = 'No se puede enviar el documento. En la pestaña ""%1"", en la línea #%2, el ""Importe"" e ""Importe en la moneda"" deben ser números del mismo tipo: positivos o negativos.';es_CO = 'No se puede enviar el documento. En la pestaña ""%1"", en la línea #%2, el ""Importe"" e ""Importe en la moneda"" deben ser números del mismo tipo: positivos o negativos.';tr = 'Belge kaydedilemiyor. ""%1"" sekmesinin %2 satırında ""Tutar"" ve ""Para biriminde tutar"" aynı türde sayılar olmalıdır: artı veya eksi.';it = 'Impossibile pubblicare il documento. Nella scheda ""%1"", nella riga #%2, ""Importo"" e ""Importo in valuta"" devono essere numeri dello stesso tipo: positivo o negativo.';de = 'Fehler beim Buchen des Dokuments. Die Nummern müssen auf  der Registerkarte ""%1"" in der Zeile Nr. %2, ""Betrag"" und ""Betrag in Währung"" denselben Typ haben: positiv oder negativ.'");
				MessageText = StringFunctionsClientServer.SubstituteParametersToString(Text,
					TabNames[TableName], LineNumbers[TableName]);
				CommonClientServer.MessageToUser(MessageText, ThisObject, , TableName, Cancel);
			EndIf;
		EndIf;
		
		If TableName = "CashAssetsBank" And (Row.AmountCur < 0 Or Row.Amount < 0) Then
			
			AllowNegativeBalance = Common.ObjectAttributeValue(Row.BankAccountPettyCash, "AllowNegativeBalance");
			
			OverdraftRows = OverdraftInfoTable.FindRows(New Structure("BankAccount", Row.BankAccountPettyCash));
			If OverdraftRows.Count() > 0 Then
				OverdraftRow = OverdraftRows[0];
			EndIf;
				
			If (Row.AmountCur < 0 Or Row.Amount < 0) And Not AllowNegativeBalance And Not OverdraftRow.UseOverdraft Then
				
				NegativeMessageTemplate = NStr("en = 'Cannot post the document.
						|On the ""%1"" tab, in line #%2, the bank account does not allow an overdraft or negative balance.'; 
						|ru = 'Не удалось провести документ.
						|На вкладке ""%1"" в строке №%2 на банковском счете не разрешен овердрафт или отрицательный остаток.';
						|pl = 'Nie można zatwierdzić dokumentu.
						|Na karcie ""%1"", w wierszu nr %2, rachunek bankowy nie dopuszcza przekroczenia stanu rachunku lub salda ujemnego.';
						|es_ES = 'No se puede enviar el documento.
						|En la pestaña ""%1"", en la línea #%2, la cuenta bancaria no permite un sobregiro o un saldo negativo.';
						|es_CO = 'No se puede enviar el documento.
						|En la pestaña ""%1"", en la línea #%2, la cuenta bancaria no permite un sobregiro o un saldo negativo.';
						|tr = 'Belge kaydedilemiyor.
						|""%1"" sekmesinin %2 satırında banka hesabı fazla para çekmeye veya eksi bakiyeye izin vermiyor.';
						|it = 'Impossibile pubblicare il documento.
						|Nella scheda ""%1"", nella riga #%2, il conto corrente non permette uno scoperto o saldo negativo.';
						|de = 'Fehler beim Buchen des Dokuments.
						|Das Bankkonto gestattet auf der Registerkarte ""%1"" in der Zeile Nr. %2, keine Kontoüberziehung oder negativen Saldo.'");
				MessageText = StringFunctionsClientServer.SubstituteParametersToString(NegativeMessageTemplate,
					TabNames[TableName], LineNumbers[TableName]);
					
				MessageField = CommonClientServer.PathToTabularSection("", LineNumbers[TableName], ?(Row.AmountCur < 0, "AmountCur", "Amount"));
				CommonClientServer.MessageToUser(MessageText, ThisObject, MessageField, TableName, Cancel);
				
			EndIf;
			
			If (Row.AmountCur < 0 Or Row.Amount < 0) And Not AllowNegativeBalance And OverdraftRow.UseOverdraft
					And (OverdraftRow.Limit < -Row.AmountCur Or OverdraftRow.Limit < -Row.Amount) Then
					
				LimitExceedMessageTemplate = NStr("en = 'Cannot post the document.
						|On the ""%1"" tab, in line #%2, the bank account has a negative balance. The overdraft limit is insufficient to cover it.'; 
						|ru = 'Не удалось провести документ.
						|На вкладке ""%1"", в строке №%2 на банковском счете имеется отрицательный остаток. Лимита овердрафта недостаточно для его покрытия.';
						|pl = 'Nie można zatwierdzić dokumentu.
						|Na karcie ""%1"", w wierszu nr %2, rachunek bankowy nie dopuszcza salda ujemnego. Limit przekroczenia stanu rachunku jest niewystarczający aby pokryć go.';
						|es_ES = 'No se puede enviar el documento.
						|En la pestaña ""%1"", en la línea #%2, la cuenta bancaria tiene un saldo negativo. El límite de sobregiro es insuficiente para cubrirlo.';
						|es_CO = 'No se puede enviar el documento.
						|En la pestaña ""%1"", en la línea #%2, la cuenta bancaria tiene un saldo negativo. El límite de sobregiro es insuficiente para cubrirlo.';
						|tr = 'Belge kaydedilemiyor.
						|""%1"" sekmesinin %2 satırında banka hesabı eksi bakiyede. Fazla para çekme limiti tutarı karşılamıyor.';
						|it = 'Impossibile pubblicare il documento.
						|Nella scheda ""%1"", nella riga #%2, il conto corrente ha un saldo negativo. Il limite di scoperto è insufficiente per coprirlo.';
						|de = 'Fehler beim Buchen des Dokuments.
						|Das Bankkonto hat auf der Registerkarte ""%1"" in der Zeile Nr. %2 einen negativen Saldo. Die Überziehungsgrenze ist nicht ausreichenden, um diesen zu decken.'");
				MessageText = StringFunctionsClientServer.SubstituteParametersToString(LimitExceedMessageTemplate,
					TabNames[TableName], LineNumbers[TableName]);
					
				MessageField = CommonClientServer.PathToTabularSection("", LineNumbers[TableName], ?(Row.AmountCur < 0, "AmountCur", "Amount"));
				CommonClientServer.MessageToUser(MessageText, ThisObject, MessageField, TableName, Cancel);
				
			EndIf;
		
		EndIf;
		
	EndDo;
	
EndProcedure

Function GetBankAccountsOverdraftInfo()
	
	Query = New Query;
	Query.Text = "SELECT ALLOWED DISTINCT
	|	BankAccounts.Ref AS BankAccount,
	|	CASE
	|		WHEN ISNULL(OverdraftLimitsSliceLast.Limit, 0) = 0
	|			THEN FALSE
	|		ELSE BankAccounts.UseOverdraft
	|	END AS UseOverdraft,
	|	ISNULL(OverdraftLimitsSliceLast.Limit, 0) AS Limit
	|FROM
	|	Catalog.BankAccounts AS BankAccounts
	|		LEFT JOIN InformationRegister.OverdraftLimits.SliceLast(
	|				,
	|				BankAccount IN (&BankAccounts)
	|					AND &DocDate >= StartDate
	|					AND (&DocDate <= EndDate
	|						OR EndDate = DATETIME(1, 1, 1))) AS OverdraftLimitsSliceLast
	|		ON (OverdraftLimitsSliceLast.BankAccount = BankAccounts.Ref)
	|WHERE
	|	BankAccounts.Ref IN(&BankAccounts)";
	
	Query.SetParameter("BankAccounts", CashAssets.UnloadColumn("BankAccountPettyCash"));
	Query.SetParameter("DocDate", Date);
	
	Return Query.Execute().Unload();
	
EndFunction

#EndRegion

#Region EventHandlers

// Procedure - event handler BeforeWrite object.
//
Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Not Constants.UseSeveralLinesOfBusiness.Get() Then
		
		For Each RowFixedAssets In FixedAssets Do
			
			If Not GetFunctionalOption("UseDefaultTypeOfAccounting") 
				Or RowFixedAssets.GLExpenseAccount.TypeOfAccount = Enums.GLAccountsTypes.Expenses Then
				
				RowFixedAssets.BusinessLine = Catalogs.LinesOfBusiness.MainLine;
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
	For Each TSRow In AccountsReceivable Do
		
		If ValueIsFilled(TSRow.Counterparty)
			And Not TSRow.Counterparty.DoOperationsByContracts
			And Not ValueIsFilled(TSRow.Contract) Then
			TSRow.Contract = TSRow.Counterparty.ContractByDefault;
		EndIf;
		
		If Autogeneration
			And Not ValueIsFilled(TSRow.Document)
			And Not TSRow.Document = Undefined Then
			TSRow.Document = GenerateDocument(TSRow);
		EndIf;
		
	EndDo;
	
	For Each TSRow In AccountsPayable Do
		
		If ValueIsFilled(TSRow.Counterparty)
			And Not TSRow.Counterparty.DoOperationsByContracts
			And Not ValueIsFilled(TSRow.Contract) Then
			TSRow.Contract = TSRow.Counterparty.ContractByDefault;
		EndIf;
		
		If Autogeneration
			And Not ValueIsFilled(TSRow.Document)
			And Not TSRow.Document = Undefined Then
			TSRow.Document = GenerateDocument(TSRow);
		EndIf;
		
	EndDo;
	
	For Each TSRow In AdvanceHolders Do
		
		If Autogeneration
			And Not ValueIsFilled(TSRow.Document)
			And Not TSRow.Document = Undefined Then
			TSRow.Document = GenerateDocument(TSRow, False);
		EndIf;
		
	EndDo;
		
	FillInventoryAcquisitionDocuments();
	
	// Change of approved documents
	AccountingApprovalServer.BeforeWriteAtServer(ThisObject, Cancel);
	// End Change of approved documents
	
	AdditionalProperties.Insert("WriteMode", WriteMode);
	AdditionalProperties.Insert("Posted", Posted);
	
	InventoryOwnershipServer.FillMainTableColumn(ThisObject, WriteMode, Cancel);
	
EndProcedure

// Procedure - event handler FillCheckProcessing object.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If Autogeneration Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "AdvanceHolders.Document");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "AccountsReceivable.Document");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "AccountsPayable.Document");
	Else
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "AdvanceHolders.DocumentNumber");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "AccountsReceivable.DocumentNumber");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "AccountsPayable.DocumentNumber");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "AdvanceHolders.DocumentDate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "AccountsReceivable.DocumentDate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "AccountsPayable.DocumentDate");
	EndIf;
	
	If Not AutogenerateInventoryAcqusitionDocuments Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Inventory.DocumentNumber");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Inventory.DocumentDate");
	EndIf;
	
	If Not AccountingSection = Enums.OpeningBalanceAccountingSections.Taxes Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "CompanyVATNumber");
	EndIf;
	
	For Each TSRow In OtherSections Do
		If TSRow.Account.Currency
			And Not ValueIsFilled(TSRow.Currency) Then
			MessageText = NStr("en = 'The ""Currency"" column is not filled in for the currency account in row No. %LineNumber% of the ""Other sections"" list.'; ru = 'Не заполнена колонка ""Валюта"" для валютного счета в строке %LineNumber% списка ""Прочие разделы"".';pl = 'Dla rachunku walutowego w wierszu %LineNumber% listy ""Inne rozdziały"" nie wypełniono kolumny ""Waluta"".';es_ES = 'La columna ""Moneda"" no está rellenada para la cuenta de monedas en la fila número %LineNumber% de la lista ""Otras secciones"".';es_CO = 'La columna ""Moneda"" no está rellenada para la cuenta de monedas en la fila número %LineNumber% de la lista ""Otras secciones"".';tr = '""Diğer bölümler"" listesinin %LineNumber% sayılı satırındaki döviz hesabı için ""Döviz"" sütunu doldurulmadı.';it = 'La colonna ""Valuta"" non è compilato per il conto ini valuta nella riga N.%LineNumber% dell''elenco ""Altre sezioni"".';de = 'Die Spalte ""Währung"" ist für das Währungskonto in der Zeile Nr. %LineNumber% der Liste ""Andere Abschnitte"" nicht ausgefüllt.'");
			MessageText = StrReplace(MessageText, "%LineNumber%", String(TSRow.LineNumber));
			DriveServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				"OtherSections",
				TSRow.LineNumber,
				"Currency",
				Cancel
			);
		EndIf;
		If TSRow.Account.Currency
			And Not ValueIsFilled(TSRow.AmountCur) Then
			MessageText = NStr("en = 'The ""Amount (cur.)"" column is not populated for the currency account in the %LineNumber% line of the ""Other sections"" list.'; ru = 'Не заполнена колонка ""Сумма (вал.)"" для валютного счета в строке %LineNumber% списка ""Прочие разделы"".';pl = 'Dla rachunku walutowego w wierszu %LineNumber% listy ""Inne rozdziały"" nie wypełniono kolumny ""Kwota (waluta)"".';es_ES = 'La columna ""Importe (moneda)"" no está poblada para la cuenta de monedas en la línea %LineNumber% de la lista ""Otras secciones"".';es_CO = 'La columna ""Importe (moneda)"" no está poblada para la cuenta de monedas en la línea %LineNumber% de la lista ""Otras secciones"".';tr = '""Diğer bölümler"" listesinin %LineNumber% sayılı satırındaki döviz hesabı için ""Tutar (döviz)"" sütunu doldurulmadı.';it = 'La colonna ""Importo (valuta)"" per il conto in valuta estera nella riga %LineNumber% della colonna ""Altre partizioni"" non viene compilata.';de = 'Die Spalte ""Betrag (Währung)"" wird für das Währungskonto in der %LineNumber% Zeile der Liste ""Andere Abschnitte"" nicht gefüllt.'");
			MessageText = StrReplace(MessageText, "%LineNumber%", String(TSRow.LineNumber));
			DriveServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				"OtherSections",
				TSRow.LineNumber,
				"AmountCur",
				Cancel
			);
		EndIf;
	EndDo;
	
	// Serial numbers
	InventoryWarehouses = Inventory.Unload(,"StructuralUnit");
	InventoryWarehouses.GroupBy("StructuralUnit","");
	For Each InventoryWarehouse In InventoryWarehouses Do
		WarehouseFilter = New Structure("StructuralUnit", InventoryWarehouse.StructuralUnit);
		RowByWarehouse = Inventory.FindRows(WarehouseFilter);
		WorkWithSerialNumbers.FillCheckingSerialNumbers(Cancel, RowByWarehouse, SerialNumbers, InventoryWarehouse.StructuralUnit, ThisObject);
	EndDo;
	
	BatchesServer.CheckFilling(ThisObject, Cancel);
	
	CheckCashAssetsFilling(Cancel, CheckedAttributes);
	
	// Expense item for FixedAssets
	If AccountingSection = Enums.OpeningBalanceAccountingSections.FixedAssets Then
		For Each RowOfFixedAssets In FixedAssets Do
			
			If RowOfFixedAssets.RegisterDepreciationCharge And Not ValueIsFilled(RowOfFixedAssets.DepreciationChargeItem) Then
				DriveServer.ShowMessageAboutError(
					ThisObject,
					StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'On the Fixed assets tab, in line #%1, an expense item is required.'; ru = 'На вкладке ""Основные средства"" в строке %1 требуется указать статью расходов.';pl = 'Na karcie Środki trwałe, w wierszu nr %1, pozycja rozchodów jest wymagana.';es_ES = 'En la pestaña Activos fijos, en la línea #%1, se requiere un artículo de gastos.';es_CO = 'En la pestaña Activos fijos, en la línea #%1, se requiere un artículo de gastos.';tr = 'Sabit kıymetler sekmesinin %1 nolu satırında gider kalemi gerekli.';it = 'Nella scheda Cespiti fissi, nella riga #%1, è richiesta una voce di uscita.';de = 'Eine Position von Ausgaben ist in der Zeile Nr. %1 auf der Registerkarte Anlagevermögen erforderlich.'"),
						RowOfFixedAssets.LineNumber),
					"FixedAssets",
					RowOfFixedAssets.LineNumber,
					"DepreciationChargeItem",
					Cancel);
			EndIf;
				
		EndDo;
	EndIf;
	
EndProcedure

// Procedure - handler of the FillingProcessor event.
//
Procedure Filling(FillingData, FillingText, StandardProcessing) Export
	
	If TypeOf(FillingData) = Type("DocumentRef.Stocktaking") Then
		FillByStocktaking(FillingData);	
	ElsIf TypeOf(FillingData) = Type("Structure") Then
		FillPropertyValues(ThisObject, FillingData);
	EndIf;
	
EndProcedure

// Procedure - event handler Posting object.
//
Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Accounting templates properties initialization.
	AccountingTemplatesPosting.InitializeAccountingTemplatesProperties(Ref, AdditionalProperties, Cancel);
	If AdditionalProperties.ForPosting.AccountingTemplatesPostingUnavailable Then
		Return;
	EndIf;
	
	// Initialization of document data
	Documents.OpeningBalanceEntry.InitializeDocumentData(Ref, AdditionalProperties);
	
	AccountingTemplatesPosting.CheckEntriesAccounts(AdditionalProperties, Cancel);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Registering in accounting sections
	If AdditionalProperties.TableForRegisterRecords.Property("TableInventoryInWarehouses") Then
		DriveServer.ReflectInventoryInWarehouses(AdditionalProperties, RegisterRecords, Cancel);
	EndIf;
	
	If AdditionalProperties.TableForRegisterRecords.Property("TableInventory") Then
		DriveServer.ReflectInventory(AdditionalProperties, RegisterRecords, Cancel);
		
		// Serial numbers
		If AdditionalProperties.TableForRegisterRecords.Property("TableSerialNumbers") Then
			DriveServer.ReflectTheSerialNumbersBalance(AdditionalProperties, RegisterRecords, Cancel);
		EndIf;
		If AdditionalProperties.TableForRegisterRecords.Property("TableSerialNumbersInWarranty") Then
			DriveServer.ReflectTheSerialNumbersOfTheGuarantee(AdditionalProperties, RegisterRecords, Cancel);
		EndIf;
		// Serial numbers
		
		// Products in reserve
		If AdditionalProperties.TableForRegisterRecords.Property("TableReservedProducts") Then
			DriveServer.ReflectReservedProducts(AdditionalProperties, RegisterRecords, Cancel);
		EndIf;
		
	EndIf;
	
	If AdditionalProperties.TableForRegisterRecords.Property("TableCashAssets") Then
		DriveServer.ReflectCashAssets(AdditionalProperties, RegisterRecords, Cancel);
	EndIf;
	
	If AdditionalProperties.TableForRegisterRecords.Property("TableAccountsReceivable") Then
		DriveServer.ReflectAccountsReceivable(AdditionalProperties, RegisterRecords, Cancel);
		DriveServer.ReflectIncomeAndExpensesCashMethod(AdditionalProperties, RegisterRecords, Cancel);
		DriveServer.ReflectUnallocatedExpenses(AdditionalProperties, RegisterRecords, Cancel);
	EndIf;
	
	If AdditionalProperties.TableForRegisterRecords.Property("TableAccountsPayable") Then
		DriveServer.ReflectAccountsPayable(AdditionalProperties, RegisterRecords, Cancel);
		DriveServer.ReflectIncomeAndExpensesCashMethod(AdditionalProperties, RegisterRecords, Cancel);
		DriveServer.ReflectUnallocatedExpenses(AdditionalProperties, RegisterRecords, Cancel);
		DriveServer.ReflectIncomeAndExpensesRetained(AdditionalProperties, RegisterRecords, Cancel);
	EndIf;
	
	If AdditionalProperties.TableForRegisterRecords.Property("TableTaxPayable") Then
		DriveServer.ReflectTaxesSettlements(AdditionalProperties, RegisterRecords, Cancel);
	EndIf;
	
	If AdditionalProperties.TableForRegisterRecords.Property("TablePayroll") Then
		DriveServer.ReflectPayroll(AdditionalProperties, RegisterRecords, Cancel);
	EndIf;
	
	If AdditionalProperties.TableForRegisterRecords.Property("TableAdvanceHolders") Then
		DriveServer.ReflectAdvanceHolders(AdditionalProperties, RegisterRecords, Cancel);
	EndIf;
	
	If AdditionalProperties.TableForRegisterRecords.Property("TableFixedAssetStatus") Then
		DriveServer.ReflectFixedAssetStatuses(AdditionalProperties, RegisterRecords, Cancel);
	EndIf;
	
	If AdditionalProperties.TableForRegisterRecords.Property("TableFixedAssetParameters") Then
		DriveServer.ReflectFixedAssetParameters(AdditionalProperties, RegisterRecords, Cancel);
	EndIf;
	
	If AdditionalProperties.TableForRegisterRecords.Property("TableFixedAssets") Then
		DriveServer.ReflectFixedAssets(AdditionalProperties, RegisterRecords, Cancel);
	EndIf;
	
	If AdditionalProperties.TableForRegisterRecords.Property("TableFixedAssetUsage") Then
		DriveServer.ReflectFixedAssetUsage(AdditionalProperties, RegisterRecords, Cancel);
	EndIf;
	
	If AdditionalProperties.TableForRegisterRecords.Property("TableInvoicesAndOrdersPayment") Then
		DriveServer.ReflectInvoicesAndOrdersPayment(AdditionalProperties, RegisterRecords, Cancel);
	EndIf;
	
	// Offline registers
	If AdditionalProperties.TableForRegisterRecords.Property("TableInventoryCostLayer") Then
		DriveServer.ReflectInventoryCostLayer(AdditionalProperties, RegisterRecords, Cancel);
	EndIf;
	
	// Accounting
	If AdditionalProperties.TableForRegisterRecords.Property("TableAccountingJournalEntries") Then
		DriveServer.ReflectAccountingJournalEntries(AdditionalProperties, RegisterRecords, Cancel);
		DriveServer.ReflectAccountingJournalEntriesSimple(AdditionalProperties, RegisterRecords, Cancel);
		DriveServer.ReflectAccountingJournalEntriesCompound(AdditionalProperties, RegisterRecords, Cancel);
		DriveServer.ReflectAccountingEntriesData(AdditionalProperties, RegisterRecords, Cancel);
		DriveServer.ReflectDocumentAccountingEntriesStatuses(ThisObject, AdditionalProperties, RegisterRecords, Cancel);
	EndIf;
	
	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);
	
	If Not Cancel Then
		WorkWithVAT.SubordinatedTaxInvoiceControl(DocumentWriteMode.UndoPosting, Ref, DeletionMark);
	EndIf;
	
	// Control
	Documents.OpeningBalanceEntry.RunControl(Ref, AdditionalProperties, Cancel);
	
	DriveServer.CreateRecordsInTasksRegisters(ThisObject, Cancel);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
	AccountingTemplatesPosting.CheckForDuplicateAccountingEntries(Ref, Company, Date, Cancel);
	
	// Subordinate documents
	If Not Cancel Then
		
		AccountingTemplatesPosting.CreateRefreshTransactionDocumentsByMode(
			Ref, DocumentWriteMode.Posting, DeletionMark, Company, Date, AdditionalProperties);
		
	EndIf;
	
EndProcedure

// Procedure - event handler UndoPosting object.
//
Procedure UndoPosting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);

	If Not Cancel Then
		WorkWithVAT.SubordinatedTaxInvoiceControl(DocumentWriteMode.UndoPosting, Ref, DeletionMark);
	EndIf;

	// Control
	Documents.OpeningBalanceEntry.RunControl(Ref, AdditionalProperties, Cancel, True);
	
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
	
	CreatedViaOpeningBalancesWizard = False;
	
	If SerialNumbers.Count() Then
		
		For Each InventoryLine In Inventory Do
			InventoryLine.SerialNumbers = "";
		EndDo;
		
		SerialNumbers.Clear();
		
	EndIf;
	
	For Each InventoryRow In Inventory Do
		
		If TypeOf(InventoryRow.Document) = Type("DocumentRef.OpeningBalanceEntry") Then
			InventoryRow.Document = Undefined;
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	// Subordinate tax invoice
	If Not Cancel 
		And AdditionalProperties.Property("WriteMode")
		And AdditionalProperties.WriteMode = DocumentWriteMode.Write Then
		
		WorkWithVAT.SubordinatedTaxInvoiceControl(AdditionalProperties.WriteMode, Ref, DeletionMark);
		
		AccountingTemplatesPosting.CreateRefreshTransactionDocumentsByMode(
			Ref, AdditionalProperties.WriteMode, DeletionMark, Company, Date, AdditionalProperties);

	EndIf;
	
EndProcedure

#EndRegion

#EndIf
