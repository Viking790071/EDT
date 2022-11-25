#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

// Procedure - "FillCheckProcessing" event handler.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If TypeOfPOS <> Enums.TypesOfPOS.OnlinePayments Then
		
		If ValueIsFilled(PettyCash) Then
			CheckPettyCash(Cancel);
		EndIf;
		
		If UseWithoutEquipmentConnection Then
			DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Peripherals");
		EndIf;
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentProcessor");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentProcessorContract");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "BankAccount");
		
	ElsIf TypeOfPOS <> Enums.TypesOfPOS.PhysicalPOS Then
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PettyCash");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Peripherals");
		
		If ValueIsFilled(PaymentProcessor) And ValueIsFilled(BankAccount) And ValueIsFilled(PaymentProcessorContract) Then
			
			ContractCurrency = Common.ObjectAttributeValue(PaymentProcessorContract, "SettlementsCurrency");
			BankAccountCurrency = Common.ObjectAttributeValue(BankAccount, "CashCurrency");
			
			If ContractCurrency <> BankAccountCurrency Then
				
				DoOperationsByContracts = Common.ObjectAttributeValue(PaymentProcessor, "DoOperationsByContracts");
				
				If DoOperationsByContracts Then
					MessageText = NStr("en = 'The bank account currency does not match the currency in the payment processor''s contract. Select another bank account.'; ru = 'Валюта банковского счета не соответствует валюте в договоре с платежной системой. Выберите другой банковский счет.';pl = 'Waluta rachunku bankowego nie jest zgodna z walutą w kontrakcie z systemem płatności. Wybierz inny rachunek bankowy.';es_ES = 'La moneda de la cuenta bancaria no coincide con la moneda del contrato del procesador de pagos. Seleccione otra cuenta bancaria.';es_CO = 'La moneda de la cuenta bancaria no coincide con la moneda del contrato del procesador de pagos. Seleccione otra cuenta bancaria.';tr = 'Banka hesabı para birimi, ödeme işlemcisinin sözleşmesindeki para birimiyle uyuşmuyor. Başka bir banka hesabı seçin.';it = 'La valuta del conto corrente non corrisponde alla valuta del contratto dell''elaboratore del pagamento. Selezionare un altro conto corrente.';de = 'Die Bankkontowährung stimmt mit der Währung des Vertrags des Zahlungsanbieters nicht überein. Wählen Sie ein anderes Bankkonto aus.'");
				Else
					MessageText = NStr("en = 'The bank account currency does not match the settlement currency (specified in the payment processor''s billing details). Select another bank account.'; ru = 'Валюта банковского счета не соответствует валюте расчетов, указанной в реквизитах платежной системы. Выберите другой банковский счет.';pl = 'Waluta rachunku bankowego nie jest zgodna z walutą rozliczeniową (określoną w kontrakcie z systemem płatności). Wybierz inny rachunek bankowy.';es_ES = 'La moneda de la cuenta bancaria no coincide con la moneda de liquidación (especificada en las liquidaciones del procesador de pagos). Seleccione otra cuenta bancaria.';es_CO = 'La moneda de la cuenta bancaria no coincide con la moneda de liquidación (especificada en las liquidaciones del procesador de pagos). Seleccione otra cuenta bancaria.';tr = 'Banka hesabı para birimi, uzlaşma para birimiyle (ödeme işlemcinin fatura bilgilerinde belirtilen) uyuşmuyor. Başka bir banka hesabı seçin.';it = 'La valuta del conto corrente non corrisponde alla valuta di regolamento (indicata nei dettagli della fatturazione dell''elaboratore del pagamento). Selezionare un altro conto corrente.';de = 'Die Bankkontowährung stimmt mit der Abrechnungswährung (angegeben in Rechnungsdetails des Zahlungsanbieters) nicht überein. Wählen Sie ein anderes Bankkonto aus.'");
				EndIf;
				
				CommonClientServer.MessageToUser(MessageText, ThisObject, "BankAccount", , Cancel);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	CheckPaymentCardTypesDuplicates(Cancel);
	
EndProcedure

Procedure Filling(FillingData, FillingText, StandardProcessing)
	
	GLAccount = Catalogs.DefaultGLAccounts.GetDefaultGLAccount("CreditCardSalesReceivedAtALaterDate");
	
	If Not TypeOf(FillingData) = Type("Structure")
		Or Not FillingData.Property("TypeOfPOS")
		Or Not ValueIsFilled(FillingData.TypeOfPOS) Then
		
		If GetFunctionalOption("UsePaymentProcessors") Then
			TypeOfPOS = Enums.TypesOfPOS.OnlinePayments;
		Else
			TypeOfPOS = Enums.TypesOfPOS.PhysicalPOS;
		EndIf;
		
	EndIf;

EndProcedure

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If UseWithoutEquipmentConnection Then
		Peripherals = Undefined;
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

Procedure CheckPaymentCardTypesDuplicates(Cancel)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	PaymentCardKinds.LineNumber AS LineNumber,
	|	PaymentCardKinds.ChargeCardKind AS ChargeCardKind
	|INTO PaymentCardKinds
	|FROM
	|	&PaymentCardKinds AS PaymentCardKinds
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(PaymentCardKinds.LineNumber) AS LineNumber,
	|	PaymentCardKinds.ChargeCardKind AS ChargeCardKind
	|INTO MinLineNumbers
	|FROM
	|	PaymentCardKinds AS PaymentCardKinds
	|
	|GROUP BY
	|	PaymentCardKinds.ChargeCardKind
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	PaymentCardKinds.LineNumber AS LineNumber,
	|	PaymentCardKinds.ChargeCardKind AS ChargeCardKind,
	|	MinLineNumbers.LineNumber AS MinLineNumber
	|FROM
	|	PaymentCardKinds AS PaymentCardKinds
	|		INNER JOIN MinLineNumbers AS MinLineNumbers
	|		ON PaymentCardKinds.ChargeCardKind = MinLineNumbers.ChargeCardKind
	|			AND PaymentCardKinds.LineNumber > MinLineNumbers.LineNumber";
	
	Query.SetParameter("PaymentCardKinds", PaymentCardKinds);
	
	Result = Query.Execute();
	
	If Not Result.IsEmpty() Then
		
		MessageTemplate = NStr("en = 'Payment card types cannot include duplicate items. Details: %1 is already specified in line %2.'; ru = 'Типы платежных карт не могут содержать повторяющиеся элементы. Подробнее: %1 уже указан в строке %2.';pl = 'Typy kart płatniczych nie mogą zawierać powtarzających się elementów. Szczegóły: %1 jest już wybrany w wierszu %2.';es_ES = 'Los tipos de tarjetas de pago no pueden incluir elementos duplicados. Detalles: %1 ya está especificado en la línea %2.';es_CO = 'Los tipos de tarjetas de pago no pueden incluir elementos duplicados. Detalles: %1 ya está especificado en la línea %2.';tr = 'Ödeme kartı türleri eş kopya öğeler içeremez. Ayrıntılar: %1 öğesi %2 satırında zaten belirtilmiş.';it = 'I tipi di carte di pagamento non possono includere elementi duplicati. Dettagli: %1 è già indicato nella riga %2.';de = 'Zahlungskartentypen können keine duplizierten Positionen enthalten. Details: %1 sind bereit in der Zeile %2 angegeben.'");
		
		Sel = Result.Select();
		While Sel.Next() Do
			
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageTemplate,
				Sel.ChargeCardKind, Sel.MinLineNumber);
			
			CommonClientServer.MessageToUser(MessageText,
				ThisObject,
				CommonClientServer.PathToTabularSection("PaymentCardKinds", Sel.LineNumber, "ChargeCardKind"),
				,
				Cancel);
			
		EndDo;
		
	EndIf;
	
EndProcedure

// Procedure checks the petty cash specified in POS terminal.
//
Procedure CheckPettyCash(Cancel)
	
	If TypeOf(PettyCash) = Type("CatalogRef.CashRegisters") Then
		Attributes = Catalogs.CashRegisters.GetCashRegisterAttributes(PettyCash);
		
		If ValueIsFilled(Company)
		   AND ValueIsFilled(Attributes.Company)
		   AND Company <> Attributes.Company Then
		
			Text = NStr("en = 'The company of the cash funds does not correspond to the company of the acquiring contract.'; ru = 'Организация кассы не соответствует организации договора эквайринга';pl = 'Organizacja kasy nie odpowiada organizacji w umowie o acquiring ';es_ES = 'La empresa de los fondos en efectivo no corresponde a la empresa del contrato de adquisición.';es_CO = 'La empresa de los fondos en efectivo no corresponde a la empresa del contrato de adquisición.';tr = 'Nakit fon iş yeri, devralma anlaşmasının iş yeriyle uyuşmuyor.';it = 'L''azienda dei fondi di liquidità non corrisponde all''azienda del contratto di acquisizione.';de = 'Die Firma der Barmittel entspricht nicht der Firma des Kartenzahlungsvertrags.'");
			CommonClientServer.MessageToUser(
				Text,
				ThisObject,
				"PettyCash",
				,
				Cancel
			);
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#EndIf