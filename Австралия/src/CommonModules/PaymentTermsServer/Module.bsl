
#Region Public

Function GetPaymentTermByBaselineDate(BaselineDate) Export
	
	If BaselineDate = Enums.BaselineDateForPayment.EmptyRef() Then
		Return Enums.PaymentTerm.EmptyRef();
		
	ElsIf BaselineDate = Enums.BaselineDateForPayment.DocumentDate 
		Or BaselineDate = Enums.BaselineDateForPayment.PostingDate Then
		
		Return Enums.PaymentTerm.PaymentInAdvance;
		
	Else
		Return Enums.PaymentTerm.Net;
	EndIf;
	
EndFunction

Function PaymentTermsPrintTitle() Export
	
	Return NStr("en = 'Payment terms'; ru = 'Условия оплаты';pl = 'Warunki płatności';es_ES = 'Términos de pagos';es_CO = 'Términos de pagos';tr = 'Ödeme şartları';it = 'Termini di pagamento';de = 'Zahlungsbedingungen'");
	
EndFunction

Function TitleStagesOfPayment(Object) Export
	
	ArrayOfString = New Array;
	TypeOfRef = TypeOf(Object.Ref);
	SetPaymentDiscountText = False;
	
	If TypeOfRef = Type("CatalogRef.Counterparties") Then
		
		SetPaymentDiscountText = (Object.Customer Or Object.Supplier);
		
		Parameters = New Structure("Ref, StagesOfPayment", Object.Ref, Object.StagesOfPayment.Unload());
		
	ElsIf TypeOfRef = Type("CatalogRef.CounterpartyContracts") Then
		
		If Object.ContractKind = Enums.ContractType.WithCustomer
			Or Object.ContractKind = Enums.ContractType.WithVendor Then
			
			SetPaymentDiscountText = True;
		EndIf;
		
		Parameters = New Structure("Ref, StagesOfPayment", Object.Ref, Object.StagesOfPayment.Unload());
		
	Else
		Parameters = New Structure("Ref, PaymentCalendar", Object.Ref, Object.PaymentCalendar.Unload());
	EndIf;
	
	StagesOfPayment = GenerateStagesOfPaymentTable(Parameters);
	
	If SetPaymentDiscountText Then
		
		PaymentDiscounts = Object.EarlyPaymentDiscounts;
		For each TableRow In PaymentDiscounts Do
			
			If ArrayOfString.Count() > 0 Then
				TextOr = StringFunctionsClientServer.SubstituteParametersToString(" %1 ", NStr("en = 'or'; ru = 'или';pl = 'albo';es_ES = 'o';es_CO = 'o';tr = 'veya';it = 'o';de = 'oder'"));
				ArrayOfString.Add(TextOr);
			EndIf;
			
			PaymentDiscountsText = StringFunctionsClientServer.SubstituteParametersToString(
				"%1/%2",
				TableRow.Discount,
				TableRow.Period);
			
			ArrayOfString.Add(PaymentDiscountsText);
			
		EndDo;
		
		If ArrayOfString.Count() > 0 Then
			ArrayOfString.Add(", ");
		EndIf;
		
	EndIf;
	
	PaymentMethod = Object.PaymentMethod;
	CountOfStagesOfPayment = StagesOfPayment.Count();
	
	Appearance = OptionAppearanceTitleStagesOfPayment();
	
	ArrayOfString.Add(StagePresentation(PaymentMethod));
	
	StagesOfPaymentText = "";
	If CountOfStagesOfPayment = 0 Then
		
		ArrayOfString.Add(", ");
		ArrayOfString.Add(NStr("en = 'payment terms are not set'; ru = 'условия оплаты не указаны';pl = 'nie ustawiono warunków płatności';es_ES = 'términos de pago no establecidos';es_CO = 'términos de pago no establecidos';tr = 'ödeme şartları belirlenmedi';it = 'i termini di pagamento non sono impostati';de = 'die Zahlungsbedingungen sind nicht festgelegt'"));
		
	ElsIf CountOfStagesOfPayment <= 2 Then
		
		ArrayOfString.Add(" ");
		For Count = 1 To CountOfStagesOfPayment Do
			
			PaymentRow = StagesOfPayment[Count - 1];
			
			StagesOfPaymentText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = '%1 %2% %3'; ru = '%1 %2% %3';pl = '%1 %2% %3';es_ES = '%1 %2% %3';es_CO = '%1 %2% %3';tr = '%1 %2% %3';it = '%1 %2% %3';de = '%1 %2% %3'"),
				Lower(StagePresentation(PaymentRow.Term)),
				PaymentRow.Percentage,
				BaselineDatePresentation(PaymentRow));

			ArrayOfString.Add(StagesOfPaymentText);
			ArrayOfString.Add(", ");
			
		EndDo;
		
		ArrayOfString.Delete(ArrayOfString.Count() - 1);
		
	Else
		ArrayOfString.Add(" ");
		
		StagesOfPaymentText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'in %1 transactions'; ru = 'в %1 этапов';pl = 'w %1 etapach';es_ES = 'en %1 transacciones';es_CO = 'en %1 transacciones';tr = '%1 işlemde';it = 'in %1 transazioni';de = 'bei %1 Transaktionen'"),
			Format(CountOfStagesOfPayment, "NZ=0"));
		
		ArrayOfString.Add(StagesOfPaymentText);
	EndIf;
	
	Return New FormattedString(ArrayOfString);
	
EndFunction

Procedure SetDecorationExampleTitle(StagesOfPayment, DecorationExample) Export 
	
	ExampleTitle = "";
	
	If StagesOfPayment.Count() > 0 Then
	
		CurrentDate = CurrentSessionDate();
		Multipliers = GetMultipliers();
	
		For Each Stage In StagesOfPayment Do
			
			If Stage.BaselineDate = Enums.BaselineDateForPayment.MonthEnd Then
				StartDate = EndOfMonth(CurrentDate);
			ElsIf Stage.BaselineDate = Enums.BaselineDateForPayment.QuarterEnd Then
				StartDate = EndOfQuarter(CurrentDate);
			Else
				StartDate = CurrentDate;
			EndIf;
			
			ExampleTitle = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = '%1, %2 date %3'; ru = '%1, %2 от %3';pl = '%1, %2 data %3';es_ES = '%1, %2 fechado %3';es_CO = '%1, %2 fechado %3';tr = '%1, %2 tarih %3';it = '%1, %2 data %3';de = '%1, %2 Datum %3'"),
				ExampleTitle,
				Lower(Stage.Term),
				Format(StartDate + 86400 * Multipliers[Stage.BaselineDate] * Stage.DuePeriod, "DLF=D"));
		
		EndDo;
	
		If Not IsBlankString(ExampleTitle) Then
			
			ExampleTitle = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'E.g.: baseline date %1%2.'; ru = 'Например: базисная дата %1%2.';pl = 'Na przykład: data bazowa %1%2.';es_ES = 'Por ejemplo: fecha de referencia %1%2.';es_CO = 'Por ejemplo: fecha de referencia %1%2.';tr = 'Örn.: başlangıç tarihi %1%2.';it = 'Es: data di base %1%2.';de = 'Z.B.: Basisdatum %1%2.'"),
				Format(CurrentDate, "DLF=D"),
				ExampleTitle);
				
		EndIf;
		
	EndIf;
	
	DecorationExample.Title = ExampleTitle;
	
EndProcedure

Procedure CheckCorrectPaymentCalendar(Object, Cancel, Amount, VATAmount) Export
	
	If Object.SetPaymentTerms Then
		
		Errors = Undefined;
		
		If Object.PaymentCalendar.Count() = 0 Then
			
			TextMessage = NStr("en = 'On the Payment terms tab, specify the payments terms or clear the Set payment terms check box.
				|Then try again.'; 
				|ru = 'На вкладке Условия оплаты укажите условия оплаты или снимите флажок Настроить условия оплаты.
				|Затем повторите попытку.';
				|pl = 'Na karcie Warunki płatności, wybierz warunki płatności lub wyczyść pole wyboru ""Ustaw warunki płatności"".
				|Następnie spróbuj ponownie.';
				|es_ES = 'En la pestaña Términos de pagos, especifique los términos de pago o desmarque la casilla de verificación Establecer los términos de pago.
				|Inténtelo de nuevo.';
				|es_CO = 'En la pestaña Términos de pagos, especifique los términos de pago o desmarque la casilla de verificación Establecer los términos de pago.
				|Inténtelo de nuevo.';
				|tr = 'Ödeme şartları sekmesinde ödeme şartlarını belirtin veya Ödeme şartlarını belirle onay kutusunu temizleyin.
				|Ardından tekrar deneyin.';
				|it = 'Nella scheda Termini di pagamento, specificare i termini di pagamento o deselezionare la casella di controllo Impostare termini di pagamento.
				| Poi riprovare.';
				|de = 'Auf der Registerkarte Zahlungsbedingungen, geben Sie die Zahlungsbedingungen an oder deaktivieren das Kontrollkästchen Zahlungsbedingungen festlegen.
				|Dann versuchen Sie es erneut.'");
			
			If TypeOf(Object) = Type("DataProcessorObject.ClosingInvoiceProcessing") Then
				CommonClientServer.MessageToUser(TextMessage, , "SetPaymentTerms", "Object" , Cancel);
			Else
				CommonClientServer.MessageToUser(TextMessage, Object, "SetPaymentTerms", , Cancel);
			EndIf;
			
		Else
			
			PaymentPercentage = Object.PaymentCalendar.Total("PaymentPercentage");
			
			If PaymentPercentage <> 100 Then
				
				TextMessage = NStr("en = 'Percetange amount in the Payment terms tab should be equal to 100%'; ru = 'На вкладке ""Условия оплаты"" некорректно указаны проценты. Сумма должна быть равна 100%';pl = 'Wartość procentowa na karcie Warunki płatności musi być równa 100%';es_ES = 'Por ciento del importe en la pestaña de los términos de Pago tiene que ser igual a 100%';es_CO = 'Por ciento del importe en la pestaña de los términos de Pago tiene que ser igual a 100%';tr = 'Ödeme şartları sekmesindeki yüzdelik tutar % 100''e eşit olmalıdır';it = 'Importo percentuale, nella scheda scheda termini di Pagamento deve essere uguale al 100%';de = 'Der Prozentsatz auf der Registerkarte Zahlungsbedingungen sollte 100% betragen.'");
				CommonClientServer.AddUserError(Errors, "", TextMessage, "");
				
			EndIf;
			
			TextMessage = NStr("en = 'Incorrect %1 in the Payment terms tab. The difference is %2'; ru = 'Неверно заполнено %1 на вкладке Условия оплаты. Отклонение составляет %2';pl = 'Niezgodność %1 na karcie Warunki płatności. Różnica wynosi %2';es_ES = 'Incorrecto %1 en la pestaña de los Términos de pago. La diferencia es %2';es_CO = 'Incorrecto %1 en la pestaña de los Términos de pago. La diferencia es %2';tr = 'Ödeme koşulları sekmesinde yanlış %1. Fark %2 kadardır';it = 'Non corretto %1 nella scheda Termini di Pagamento. La differenza è %2';de = 'Fehlerhaft %1 auf der Registerkarte Zahlungsbedingungen. Der Unterschied ist %2'");
			
			PaymentAmount = Object.PaymentCalendar.Total("PaymentAmount");
			PaymentVATAmount = Object.PaymentCalendar.Total("PaymentVATAmount");
			
			If (PaymentAmount <> Amount OR VATAmount <> PaymentVATAmount) AND PaymentPercentage = 100 Then
				
				AmountForCorrectBalance = 0;
				VATForCorrectBalance = 0;
				
				For Each Line In Object.PaymentCalendar Do
					
					Line.PaymentAmount = Round(Amount * Line.PaymentPercentage / 100, 2, RoundMode.Round15as20);
					Line.PaymentVATAmount = Round(VATAmount * Line.PaymentPercentage / 100, 2, RoundMode.Round15as20);
					
					AmountForCorrectBalance = AmountForCorrectBalance + Line.PaymentAmount;
					VATForCorrectBalance = VATForCorrectBalance + Line.PaymentVATAmount;
					
				EndDo;
				
				Line.PaymentAmount = Line.PaymentAmount + (Amount - AmountForCorrectBalance);
				Line.PaymentVATAmount = Line.PaymentVATAmount + (VATAmount - VATForCorrectBalance);
				
				PaymentAmount = Object.PaymentCalendar.Total("PaymentAmount");
				PaymentVATAmount = Object.PaymentCalendar.Total("PaymentVATAmount");
				
			EndIf;
			
			If PaymentAmount <> Amount Then
				
				QuantityPayment = Amount - PaymentAmount;
				NameOfItem = NStr("en = 'payment amount'; ru = 'сумма платежа';pl = 'kwota płatności';es_ES = 'importe de pago';es_CO = 'importe de pago';tr = 'ödeme tutarı';it = 'importo del pagamento';de = 'Zahlungsbetrag'");
				TextError = StringFunctionsClientServer.SubstituteParametersToString(TextMessage, NameOfItem, QuantityPayment);
				
				CommonClientServer.AddUserError(Errors, "", TextError, "");
				
			EndIf;
			
			If VATAmount <> PaymentVATAmount Then
				
				QuantityVAT = VATAmount - PaymentVATAmount;
				NameOfItem = NStr("en = 'VAT amount'; ru = 'Сумма НДС';pl = 'Kwota VAT';es_ES = 'Importe del IVA';es_CO = 'Importe del IVA';tr = 'KDV tutarı';it = 'Importo IVA';de = 'USt.-Betrag'");
				TextError = StringFunctionsClientServer.SubstituteParametersToString(TextMessage, NameOfItem, QuantityVAT);
				
				CommonClientServer.AddUserError(Errors, "", TextError, "");
				
			EndIf;
			
		EndIf;
		
		If Object.CashAssetType = Enums.CashAssetTypes.Cash
			AND Not ValueIsFilled(Object.PettyCash) Then
			
			TextMessage = NStr("en = 'Fill-in the Cash account'; ru = 'Не заполнено поле Касса';pl = 'Wypełnij pole kasa';es_ES = 'Rellenar la cuenta de Efectivo';es_CO = 'Rellenar la cuenta de Efectivo';tr = 'Kasa hesabını doldur';it = 'Compilate il conto di cassa';de = 'Liquiditätskonto ausfüllen'");
			CommonClientServer.AddUserError(Errors, "", TextMessage, "");
				
		EndIf;
		
		If Object.CashAssetType = Enums.CashAssetTypes.Noncash
			AND Not ValueIsFilled(Object.BankAccount) Then
			
			TextMessage = NStr("en = 'Fill-in the Bank account'; ru = 'Не заполнено поле Банковский счет';pl = 'Wypełnij pole rachunek bankowy';es_ES = 'Rellenar la cuenta del Banco';es_CO = 'Rellenar la cuenta del Banco';tr = 'Banka hesabını doldur';it = 'Compilate il conto corrente';de = 'Bankkonto ausfüllen'");
			CommonClientServer.AddUserError(Errors, "", TextMessage, "");
				
		EndIf;
		
		If Errors <> Undefined Then
			
			CommonClientServer.ReportErrorsToUser(Errors, Cancel);
			
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure FillPaymentCalendarFromContract(Object, IsEnabledManually = False) Export 
	
	Var Result;
	
	Object.PaymentCalendar.Clear();
	
	If Not GetContractPaymentStages(Object, Result) Then
		
		If Not Result.ContractData.IsEmpty() Then
			ContractData = Result.ContractData.Unload();
			FillPropertyValues(Object, ContractData[0]);
		EndIf;
		
		If IsEnabledManually Then
			FillPaymentCalendarWithoutSource(Object);
		Else
			Object.SetPaymentTerms = False;
		EndIf;
		
		Return;
		
	EndIf;
	
	DocumentMetadata = Object.Ref.Metadata();
	
	TotalAmountForCorrectBalance = 0;
	TotalVATForCorrectBalance = 0;
	
	Totals = PaymentTermsClientServer.CalculateDocumentAmountVATAmountTotals(Object);
	
	StagesOfPayment = New Structure("
		|PaymentTerm, 
		|PaymentBaselineDate, 
		|PaymentDuePeriod, 
		|PaymentDate, 
		|PaymentPercentage, 
		|PaymentAmount, 
		|PaymentVATAmount,
		|CashFlowItem");
	
	Selection = Result.StagesOfPayment.Select();
	While Selection.Next() Do
		
		NewLine = Object.PaymentCalendar.Add();
		
		FillPropertyValues(StagesOfPayment, Selection);
		
		BaselineDate = CalculateBaselineDate(Object, Selection.AttributeName);
		StagesOfPayment.PaymentDate = CalculatePaymentDate(Object, Selection, BaselineDate, NewLine.LineNumber);
		
		StagesOfPayment.PaymentPercentage = Selection.PaymentPercentage;
		StagesOfPayment.PaymentAmount = Round(
			Totals.Amount * StagesOfPayment.PaymentPercentage / 100, 2, RoundMode.Round15as20);
		StagesOfPayment.PaymentVATAmount = Round(
			Totals.VATAmount * StagesOfPayment.PaymentPercentage / 100, 2, RoundMode.Round15as20);
		
		TotalAmountForCorrectBalance = TotalAmountForCorrectBalance + StagesOfPayment.PaymentAmount;
		TotalVATForCorrectBalance = TotalVATForCorrectBalance + StagesOfPayment.PaymentVATAmount;
		
		FillPropertyValues(NewLine, StagesOfPayment);
		
	EndDo;
	
	// correct balance
	StagesOfPayment.PaymentAmount = StagesOfPayment.PaymentAmount + (Totals.Amount - TotalAmountForCorrectBalance);
	StagesOfPayment.PaymentVATAmount = StagesOfPayment.PaymentVATAmount + (Totals.VATAmount - TotalVATForCorrectBalance);
	
	FillPropertyValues(NewLine, StagesOfPayment);
	
	ContractData = Result.ContractData.Unload();
	FillPropertyValues(Object, ContractData[0]);
		
	If Object.CashAssetType = Enums.CashAssetTypes.Noncash Then
		BankAccountByDefault = Common.ObjectAttributeValue(Object.Company, "BankAccountByDefault");
		If ValueIsFilled(BankAccountByDefault) Then
			Object.BankAccount = BankAccountByDefault;
		EndIf;
	ElsIf Object.CashAssetType = Enums.CashAssetTypes.Cash Then
		PettyCashByDefault = Common.ObjectAttributeValue(Object.Company, "PettyCashByDefault");
		If ValueIsFilled(PettyCashByDefault) Then
			Object.PettyCash = PettyCashByDefault;
		EndIf;
	EndIf;
	
	PaymentCalendarMetadata = DocumentMetadata.TabularSections.PaymentCalendar;
	If PaymentCalendarMetadata.Attributes.Find("PaymentDate") <> Undefined Then
		Object.PaymentCalendar.Sort("PaymentDate");
	EndIf;
	
	SetPaymentTerms(Object);
	
EndProcedure

Procedure FillPaymentCalendarFromDocument(Object, FillingData) Export 
	
	If TypeOf(FillingData) = Type("Array") Then
		
		If FillingData.Count() = 0 Then
			FillPaymentCalendarFromContract(Object);
			Return;
		EndIf;
		
		BasisDocument = FillingData[0];
		
	ElsIf FillingData = Undefined Then
		
		FillPaymentCalendarFromContract(Object);
		Return;
		
	Else
		BasisDocument = FillingData;
	EndIf;
	
	If BasisDocument.PaymentCalendar.Count() = 0 Or Not BasisDocument.SetPaymentTerms Then
		SetPaymentTerms(Object);
		Return;
	EndIf;
	
	BasisDocumentName = BasisDocument.Metadata().Name;
		
	Query = New Query;
	Query.Text = 
	"SELECT
	|	*,
	|	CASE
	|		WHEN Calendar.PaymentBaselineDate = VALUE(Enum.BaselineDateForPayment.InvoicePostingDate)
	|			THEN ""InvoicePostingDate""
	|		WHEN Calendar.PaymentBaselineDate = VALUE(Enum.BaselineDateForPayment.MonthEnd)
	|			THEN ""MonthEnd""
	|		WHEN Calendar.PaymentBaselineDate = VALUE(Enum.BaselineDateForPayment.QuarterEnd)
	|			THEN ""QuarterEnd""
	|		WHEN Calendar.PaymentBaselineDate = VALUE(Enum.BaselineDateForPayment.DocumentDate)
	|			THEN ""DocumentDate""
	|		ELSE ""PostingDate""
	|	END AS AttributeName
	|FROM
	|	Document." + BasisDocumentName + ".PaymentCalendar AS Calendar
	|WHERE
	|	Calendar.Ref = &BasisDocument";
	
	Query.SetParameter("Date", ?(ValueIsFilled(Object.Date), Object.Date, CurrentSessionDate()));
	Query.SetParameter("BasisDocument", BasisDocument);
		
	BasisPaymentCalendar = Query.Execute().Unload();
	InterimPaymentCalendar = Object.PaymentCalendar.Unload(New Array);
	BaselineDatesForCalculation = GetBaselineDatesForCalculation(Object, BasisDocument);
		
	Result = Undefined;
	GetContractPaymentStages(Object, Result);
	ContractPaymentStages = Result.StagesOfPayment.Unload();
	
	For Each BasisRow In BasisPaymentCalendar Do
		
		InterimRow = InterimPaymentCalendar.Add();
		
		For Each Column In InterimPaymentCalendar.Columns Do
			
			ColumnIsFilled = False;
			If Not BasisPaymentCalendar.Columns.Find(Column.Name) = Undefined Then
				InterimRow[Column.Name] = BasisRow[Column.Name];
				ColumnIsFilled = True;
			EndIf;
			
			If Not BaselineDatesForCalculation.Find(BasisRow.PaymentBaselineDate) = Undefined Or Not ColumnIsFilled Then
				
				If Column.Name = "PaymentDate" Then
					
					PaymentTerms = New Structure(
						"PaymentBaselineDate, PaymentDuePeriod, PaymentTerm",
						Enums.BaselineDateForPayment.EmptyRef(), 0, Enums.PaymentTerm.EmptyRef());
						
					ContractData = ContractPaymentStages.Find(BasisRow.PaymentBaselineDate, "PaymentBaselineDate");
					If ContractData = Undefined Then
						FillPropertyValues(PaymentTerms, BasisRow);
					Else
						FillPropertyValues(PaymentTerms, ContractData);
						ContractPaymentStages.Delete(ContractData);
					EndIf;
					
					BaselineDate = CalculateBaselineDate(Object, BasisRow.AttributeName);
					InterimRow.PaymentDate = CalculatePaymentDate(Object, PaymentTerms, BaselineDate, InterimRow.LineNumber);
					
				EndIf;
				
			EndIf;
			
		EndDo;
		
	EndDo;
	
	Object.PaymentCalendar.Load(InterimPaymentCalendar);
	
	SetPaymentTerms(Object);
	
EndProcedure

Procedure ShiftPaymentCalendarDates(Object, Form) Export
	
	Var CurrentDate, PreviousDate;
	
	If Not Object.SetPaymentTerms Then
		Return;
	EndIf;
	
	PaymentDatesChanged = False;
	DocumentMetadata = Object.Ref.Metadata();
	DatesStructure = FillDocumentDatesStructure(Object, Form);
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	DatesTable.InvoicePostingDate AS InvoicePostingDate,
	|	DatesTable.MonthEnd AS MonthEnd,
	|	DatesTable.PostingDate AS PostingDate,
	|	DatesTable.QuarterEnd AS QuarterEnd,
	|	DatesTable.DocumentDate AS DocumentDate
	|INTO TT_DatesTable
	|FROM
	|	&DatesTable AS DatesTable
	|WHERE
	|	DatesTable.DocumentName = &DocumentName
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	PaymentCalendar.PaymentBaselineDate AS PaymentBaselineDate,
	|	PaymentCalendar.PaymentDate AS PaymentDate
	|INTO TT_PaymentCalendar
	|FROM
	|	&PaymentCalendar AS PaymentCalendar
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_PaymentCalendar.PaymentDate AS PaymentDate,
	|	TT_PaymentCalendar.PaymentBaselineDate AS PaymentBaselineDate,
	|	CASE
	|		WHEN TT_PaymentCalendar.PaymentBaselineDate = VALUE(Enum.BaselineDateForPayment.InvoicePostingDate)
	|			THEN ISNULL(TT_DatesTable.InvoicePostingDate, """")
	|		WHEN TT_PaymentCalendar.PaymentBaselineDate = VALUE(Enum.BaselineDateForPayment.MonthEnd)
	|			THEN ISNULL(TT_DatesTable.MonthEnd, """")
	|		WHEN TT_PaymentCalendar.PaymentBaselineDate = VALUE(Enum.BaselineDateForPayment.QuarterEnd)
	|			THEN ISNULL(TT_DatesTable.QuarterEnd, """")
	|		WHEN TT_PaymentCalendar.PaymentBaselineDate = VALUE(Enum.BaselineDateForPayment.DocumentDate)
	|			THEN ISNULL(TT_DatesTable.DocumentDate, """")
	|		ELSE ISNULL(TT_DatesTable.PostingDate, """")
	|	END AS AttributeName
	|FROM
	|	TT_PaymentCalendar AS TT_PaymentCalendar
	|		LEFT JOIN TT_DatesTable AS TT_DatesTable
	|		ON (TRUE)";
	
	Query.SetParameter("PaymentCalendar", Object.PaymentCalendar.Unload());
	Query.SetParameter("DatesTable", GetDatesTable());
	Query.SetParameter("DocumentName", DocumentMetadata.Name);
	
	PaymentData = Query.Execute().Unload();
	For Each Row In Object.PaymentCalendar Do
		
		If Row.PaymentDate = Date(1,1,1) Then
			Continue;
		EndIf;
		
		PaymentInfo = PaymentData.FindRows(
			New Structure("PaymentDate, PaymentBaselineDate", Row.PaymentDate, Row.PaymentBaselineDate));
			
		If PaymentInfo.Count() > 0 Then
			
			AttributeName = PaymentInfo[0].AttributeName;
			
			If StrFind(AttributeName, ".") = 0
				And DatesStructure.CurrentDates.Property(AttributeName, CurrentDate) 
				And DatesStructure.PreviousDates.Property(AttributeName, PreviousDate) 
				And CurrentDate <> PreviousDate Then
				
				PreviousPaymentDate = Row.PaymentDate;
				
				If Row.PaymentBaselineDate = Enums.BaselineDateForPayment.MonthEnd Then
					Row.PaymentDate = AddMonth(
						Row.PaymentDate, DriveServer.DateDiff(PreviousDate, CurrentDate, Enums.Periodicity.Month));
				ElsIf Row.PaymentBaselineDate = Enums.BaselineDateForPayment.QuarterEnd Then
					Row.PaymentDate = AddMonth(
						Row.PaymentDate, 3 * Int(DriveServer.DateDiff(PreviousDate, CurrentDate, Enums.Periodicity.Quarter)))
				Else
					Row.PaymentDate = Row.PaymentDate - (BegOfDay(PreviousDate) - BegOfDay(CurrentDate));
				EndIf;
				
				If PreviousPaymentDate <> Row.PaymentDate Then
					PaymentDatesChanged = True;
				EndIf;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	For Each Attribute In DatesStructure.CurrentDates Do
		
		If Attribute.Key = "Date" Then
			Form.DocumentDate = Attribute.Value;
		ElsIf Attribute.Key = "Start" Then
			Form.StartDate = Attribute.Value;
		Else
			Form[Attribute.Key] = Attribute.Value;
		EndIf;
		
	EndDo;
	
	If PaymentDatesChanged Then
		
		MessageString = NStr("en = 'Payment terms have been changed'; ru = 'Условия оплаты изменены';pl = 'Warunki płatności zostały zmienione';es_ES = 'Se han cambiado las condiciones de pago';es_CO = 'Se han cambiado las condiciones de pago';tr = 'Ödeme şartları değiştirildi';it = 'I termini di pagamento sono stati modificati';de = 'Zahlungsbedingungen wurden geändert'");
		CommonClientServer.MessageToUser(MessageString);
		
	EndIf;
	
EndProcedure

Function RecalculateAmountForExpectedPayments(StructureAdditionalProperties, CalculatingTable, Content) Export
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TemporaryTableOrdersTotal.DoOperationsByOrders AS DoOperationsByOrders,
	|	TemporaryTableOrdersTotal.Order AS Order,
	|	TemporaryTableOrdersTotal.Total AS Total
	|FROM
	|	TemporaryTableOrdersTotal AS TemporaryTableOrdersTotal
	|WHERE
	|	TemporaryTableOrdersTotal.DoOperationsByOrders";
	
	QueryResult = Query.Execute();
	If QueryResult.IsEmpty() Then
		Return CalculatingTable;
	EndIf;
	
	TotalsSelection = QueryResult.Select();
	While TotalsSelection.Next() Do
		
		AmountTotal = TotalsSelection.Total;
		
		CalculatingRows = CalculatingTable.FindRows(
			New Structure("Order, ContentOfAccountingRecord", TotalsSelection.Order, Content));
		
		For Each CalculatingRow In CalculatingRows Do
			AmountTotal = AmountTotal - CalculatingRow.AmountForPaymentCur;
		EndDo;
		
		If AmountTotal <> 0 And CalculatingRows.Count() > 0 Then
			CalculatingRow.AmountForPayment = ?(CalculatingRow.AmountForPayment = 0, 0,
				(CalculatingRow.AmountForPaymentCur + AmountTotal) 
				* CalculatingRow.AmountForPaymentCur / CalculatingRow.AmountForPayment);
			CalculatingRow.AmountForPaymentCur = CalculatingRow.AmountForPaymentCur + AmountTotal;
		EndIf;
		
	EndDo;
	
	Return CalculatingTable;
	
EndFunction

Function PaymentInAdvanceDates() Export 
	
	AdvanceDates = New Array;
	
	AdvanceDates.Add(Enums.BaselineDateForPayment.DocumentDate);
	AdvanceDates.Add(Enums.BaselineDateForPayment.PostingDate);
	
	Return AdvanceDates;
	
EndFunction

Function NetPaymentDates() Export 
	
	NetDates = New Array;
	
	NetDates.Add(Enums.BaselineDateForPayment.InvoicePostingDate);
	NetDates.Add(Enums.BaselineDateForPayment.MonthEnd);
	NetDates.Add(Enums.BaselineDateForPayment.QuarterEnd);
	
	Return NetDates;
	
EndFunction

Procedure CheckRequiredAttributes(Object, CheckedAttributes, Cancel) Export
	
	If Object.SetPaymentTerms Then
		
		If Object.CashAssetType = Enums.CashAssetTypes.Cash Then
			DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "BankAccount");
		EndIf;
		
		If Object.CashAssetType = Enums.CashAssetTypes.Noncash Then
			DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PettyCash");
		EndIf;
		
		If Object.PaymentCalendar.Count() = 1
			And Not Object.Metadata().TabularSections.PaymentCalendar.Attributes.Find("PaymentDate") = Undefined 
			And Not ValueIsFilled(Object.PaymentCalendar[0].PaymentDate) Then
		
			MessageText = NStr("en = 'The payment date is required.'; ru = 'Поле ""Дата оплаты"" не заполнено.';pl = 'Wymagana jest data płatności.';es_ES = 'Se requiere la fecha de pago.';es_CO = 'Se requiere la fecha de pago.';tr = 'Ödeme tarihi gerekli.';it = 'È richiesta la data di pagamento.';de = 'Der Zahlungstermin ist ein Pflichtfeld.'");
			DriveServer.ShowMessageAboutError(Object, MessageText, , , "PaymentDate", Cancel);
			
			DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentCalendar.PaymentDate");
			
		EndIf;
		
	Else
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "BankAccount");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PettyCash");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentCalendar.PaymentDate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentCalendar.PaymentPercentage");
		
	EndIf;
	
EndProcedure

#EndRegion 

#Region Private

Function GetMultipliers()
	
	Map = New Map;
	
	BaselineDateManager = Enums.BaselineDateForPayment;
	BaselineDateMetadata = Metadata.Enums.BaselineDateForPayment;
	
	For Each Value In BaselineDateMetadata.EnumValues Do
		
		If BaselineDateManager[Value.Name] = BaselineDateManager.DocumentDate Then
			Multiplier = -1;
		Else
			Multiplier = 1;
		EndIf;
		
		Map.Insert(BaselineDateManager[Value.Name], Multiplier);
		
	EndDo;
	
	Map.Insert(BaselineDateManager.EmptyRef(), 0);
	
	Return Map;
	
EndFunction

Function GenerateStagesOfPaymentTable(Parameters)
	
	DefaultDocument = Documents.PurchaseOrder.EmptyRef();
	DefaultCatalog = Catalogs.CounterpartyContracts.EmptyRef();
	
	Query = New Query;
	QueryText =
	"SELECT
	|	StagesOfPayment.Term AS Term,
	|	StagesOfPayment.PaymentPercentage AS Percentage,
	|	StagesOfPayment.DuePeriod AS DuePeriod,
	|	StagesOfPayment.BaselineDate = VALUE(Enum.BaselineDateForPayment.DocumentDate) AS ShiftDown,
	|	StagesOfPayment.BaselineDate AS BaselineDate,
	|	FALSE AS ExactDate
	|INTO TT_StagesOfPayment
	|FROM
	|	&StagesOfPayment AS StagesOfPayment
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	&PaymentTerm AS PaymentTerm,
	|	PaymentCalendar.PaymentPercentage AS PaymentPercentage,
	|	&DuePeriod AS DuePeriod,
	|	&ShiftDown AS ShiftDown,
	|	&PaymentBaselineDate AS PaymentBaselineDate,
	|	&ExactDate AS ExactDate
	|INTO TT_PaymentCalendar
	|FROM
	|	&PaymentCalendar AS PaymentCalendar
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_StagesOfPayment.Term AS Term,
	|	TT_StagesOfPayment.Percentage AS Percentage,
	|	TT_StagesOfPayment.DuePeriod AS DuePeriod,
	|	TT_StagesOfPayment.ShiftDown AS ShiftDown,
	|	TT_StagesOfPayment.BaselineDate AS BaselineDate,
	|	TT_StagesOfPayment.ExactDate AS ExactDate
	|FROM
	|	TT_StagesOfPayment AS TT_StagesOfPayment
	|
	|UNION ALL
	|
	|SELECT
	|	TT_PaymentCalendar.PaymentTerm,
	|	TT_PaymentCalendar.PaymentPercentage,
	|	TT_PaymentCalendar.DuePeriod,
	|	TT_PaymentCalendar.ShiftDown,
	|	TT_PaymentCalendar.PaymentBaselineDate,
	|	TT_PaymentCalendar.ExactDate
	|FROM
	|	TT_PaymentCalendar AS TT_PaymentCalendar";
	
	Query.SetParameter("StagesOfPayment", DefaultCatalog.StagesOfPayment.Unload());
	Query.SetParameter("PaymentCalendar", DefaultDocument.PaymentCalendar.Unload());
	
	FillPropertyValues(Query.Parameters, Parameters);
	
	If TypeOf(Parameters.Ref) = Type("DocumentRef.Quote") Or TypeOf(Parameters.Ref) = Type("DocumentRef.SupplierQuote") Then
		
		QueryText = StrReplace(QueryText, "&PaymentTerm", "PaymentCalendar.PaymentTerm");
		QueryText = StrReplace(QueryText, "&DuePeriod", "PaymentCalendar.PaymentDuePeriod");
		QueryText = StrReplace(QueryText, "&ShiftDown",
			"PaymentCalendar.PaymentBaselineDate = VALUE(Enum.BaselineDateForPayment.DocumentDate)");
		QueryText = StrReplace(QueryText, "&PaymentBaselineDate", "PaymentCalendar.PaymentBaselineDate");
		QueryText = StrReplace(QueryText, "&ExactDate", "FALSE"); 
		
	Else
		
		Query.SetParameter("PaymentTerm", NStr("en = 'payment'; ru = 'платеж';pl = 'płatność';es_ES = 'pago';es_CO = 'pago';tr = 'ödeme';it = 'Pagamento';de = 'Zahlung'"));
		
		QueryText = StrReplace(QueryText, "&DuePeriod", "PaymentCalendar.PaymentDate");
		QueryText = StrReplace(QueryText, "&ShiftDown", "TRUE");
		QueryText = StrReplace(QueryText, "&PaymentBaselineDate", """""");
		QueryText = StrReplace(QueryText, "&ExactDate", "TRUE");
		
	EndIf;

	Query.Text = QueryText;
	
	Return Query.Execute().Unload();
	
EndFunction

Function StagePresentation(PaymentMethod, PresentationForEmpty = True)
	
	Presentation = "";
	
	If Not ValueIsFilled(PaymentMethod) Then
		If PresentationForEmpty Then
			Presentation = NStr("en = 'Not specified'; ru = 'Не указан';pl = 'Nie określono';es_ES = 'No especificado';es_CO = 'No especificado';tr = 'Belirtilmemiş';it = 'Non specificato';de = 'Keine Angabe'");
		EndIf;
	ElsIf PaymentMethod = Enums.CashAssetTypes.Cash Then
		Presentation = NStr("en = 'Cash payment'; ru = 'Форма оплаты: наличными';pl = 'Płatność gotówkowa';es_ES = 'Pago en efectivo';es_CO = 'Pago en efectivo';tr = 'Nakit ödeme';it = 'Pagamento in contanti';de = 'Barzahlung'");
	ElsIf PaymentMethod = Enums.CashAssetTypes.Noncash Then
		Presentation = NStr("en = 'Electronic payment'; ru = 'Форма оплаты: безналичная';pl = 'Płatność bezgotówkowa';es_ES = 'Pago electrónico';es_CO = 'Pago electrónico';tr = 'Elektronik ödeme';it = 'Pagamento non in contanti';de = 'Elektronische Zahlung'");
	Else
		Presentation = String(PaymentMethod);
	EndIf;
	
	Return Presentation;
	
EndFunction

Function BaselineDatePresentation(PaymentRow)
	
	If PaymentRow.ExactDate Then
		
		Template = NStr("en = 'on %1'; ru = 'на %1';pl = 'na %1';es_ES = 'en %1';es_CO = 'en %1';tr = '%1 gününde';it = 'il %1';de = 'am %1'");
		
		Presentation = StringFunctionsClientServer.SubstituteParametersToString(Template, Format(PaymentRow.DuePeriod, "DLF=D")); 
		
	Else
		
		Template = NStr("en = '%1 day(s) %2 %3'; ru = '%1 день(дней) %2 %3';pl = '%1 dzień(dni) %2 %3';es_ES = '%1 día(s) %2 %3';es_CO = '%1 día(s) %2 %3';tr = '%1 gün %2 %3';it = '%1 giorno(/i)%2 %3';de = '%1 Tag(e) %2 %3'");
		
		Presentation = StringFunctionsClientServer.SubstituteParametersToString(
			Template,
			PaymentRow.DuePeriod,
			?(PaymentRow.ShiftDown, NStr("en = 'before'; ru = 'до';pl = 'do';es_ES = 'antes';es_CO = 'antes';tr = 'önce';it = 'prima';de = 'vor'"), NStr("en = 'after'; ru = 'после';pl = 'po';es_ES = 'después';es_CO = 'después';tr = 'sonra';it = 'dopo';de = 'nach'")),
			Lower(PaymentRow.BaselineDate));
		
	EndIf;
		
	Return Presentation;
	
EndFunction

Function OptionAppearanceTitleStagesOfPayment()
	
	Options = New Structure();
	
	Options.Insert("ColorAttention", WebColors.FireBrick);
	Options.Insert("ColorSelect", StyleColors.TitleStagesOfPaymentColor);
	Options.Insert("DateFormat", "DLF=D");
	Options.Insert("PartFormat","ND=3; NFD=; NZ=0");
	
	Return Options;
	
EndFunction

Function GetDatesTable()
	
	RulesTemplate = GetCommonTemplate("BaselineDateCalculationRules");
		
	Builder = New QueryBuilder;
	Builder.DataSource = New DataSourceDescription(RulesTemplate.Area());
	Builder.Execute();
	
	Return Builder.Result.Unload();
		
EndFunction

Function FillDocumentDatesStructure(Object, Form)
	
	CurrentDates = New Structure;
	CurrentDates.Insert("Date", Object.Date);
	
	PreviousDates = New Structure;
	PreviousDates.Insert("Date", Form.DocumentDate);
	
	TypeOfRef = TypeOf(Object.Ref);
	If TypeOfRef = Type("DocumentRef.PurchaseOrder") Then
		CurrentDates.Insert("ReceiptDate", Object.ReceiptDate);
		PreviousDates.Insert("ReceiptDate", Form.ReceiptDate);
	ElsIf TypeOfRef = Type("DocumentRef.SalesOrder") Then
		CurrentDates.Insert("ShipmentDate", Object.ShipmentDate);
		PreviousDates.Insert("ShipmentDate", Form.ShipmentDate);
	ElsIf TypeOfRef = Type("DocumentRef.SupplierInvoice") Then
		CurrentDates.Insert("IncomingDocumentDate", Object.IncomingDocumentDate);
		PreviousDates.Insert("IncomingDocumentDate", Form.IncomingDocumentDate);
	ElsIf TypeOfRef = Type("DocumentRef.WorkOrder") Then
		CurrentDates.Insert("Start", Object.Start);
		PreviousDates.Insert("Start", Form.StartDate);
	EndIf;
	
	Return New Structure("CurrentDates, PreviousDates", CurrentDates, PreviousDates);
	
EndFunction

Function GetContractPaymentStages(Object, Result)
	
	DocumentMetadata = Object.Ref.Metadata();
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	DatesTable.InvoicePostingDate AS InvoicePostingDate,
	|	DatesTable.MonthEnd AS MonthEnd,
	|	DatesTable.PostingDate AS PostingDate,
	|	DatesTable.QuarterEnd AS QuarterEnd,
	|	DatesTable.DocumentDate AS DocumentDate
	|INTO TT_DatesTable
	|FROM
	|	&DatesTable AS DatesTable
	|WHERE
	|	DatesTable.DocumentName = &DocumentName
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	CounterpartyContracts.Ref AS Ref,
	|	CounterpartyContracts.PaymentMethod AS PaymentMethod,
	|	CASE
	|		WHEN CounterpartyContracts.PaymentMethod = VALUE(Catalog.PaymentMethods.Electronic)
	|			THEN VALUE(Enum.CashAssetTypes.Noncash)
	|		WHEN CounterpartyContracts.PaymentMethod = VALUE(Catalog.PaymentMethods.Cash)
	|			THEN VALUE(Enum.CashAssetTypes.Cash)
	|		ELSE VALUE(Enum.CashAssetTypes.EmptyRef)
	|	END AS CashAssetType,
	|	CounterpartyContracts.CashFlowItem AS CashFlowItem
	|INTO TT_CounterpartyContracts
	|FROM
	|	Catalog.CounterpartyContracts AS CounterpartyContracts
	|WHERE
	|	CounterpartyContracts.Ref = &Contract
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_CounterpartyContracts.PaymentMethod AS PaymentMethod,
	|	TT_CounterpartyContracts.CashAssetType AS CashAssetType
	|FROM
	|	TT_CounterpartyContracts AS TT_CounterpartyContracts
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	CASE
	|		WHEN StagesOfPayment.BaselineDate = VALUE(Enum.BaselineDateForPayment.InvoicePostingDate)
	|			THEN ISNULL(TT_DatesTable.InvoicePostingDate, """")
	|		WHEN StagesOfPayment.BaselineDate = VALUE(Enum.BaselineDateForPayment.MonthEnd)
	|			THEN ISNULL(TT_DatesTable.MonthEnd, """")
	|		WHEN StagesOfPayment.BaselineDate = VALUE(Enum.BaselineDateForPayment.QuarterEnd)
	|			THEN ISNULL(TT_DatesTable.QuarterEnd, """")
	|		WHEN StagesOfPayment.BaselineDate = VALUE(Enum.BaselineDateForPayment.DocumentDate)
	|			THEN ISNULL(TT_DatesTable.DocumentDate, """")
	|		ELSE ISNULL(TT_DatesTable.PostingDate, """")
	|	END AS AttributeName,
	|	StagesOfPayment.Term AS PaymentTerm,
	|	StagesOfPayment.BaselineDate AS PaymentBaselineDate,
	|	StagesOfPayment.DuePeriod AS PaymentDuePeriod,
	|	StagesOfPayment.PaymentPercentage AS PaymentPercentage,
	|	TT_CounterpartyContracts.CashFlowItem AS CashFlowItem
	|FROM
	|	TT_CounterpartyContracts AS TT_CounterpartyContracts
	|		INNER JOIN Catalog.CounterpartyContracts.StagesOfPayment AS StagesOfPayment
	|		ON TT_CounterpartyContracts.Ref = StagesOfPayment.Ref
	|		LEFT JOIN TT_DatesTable AS TT_DatesTable
	|		ON (TRUE)";
	
	Query.SetParameter("Contract", Object.Contract);
	Query.SetParameter("DatesTable", GetDatesTable());
	Query.SetParameter("DocumentName", DocumentMetadata.Name);
	
	QueryResult = Query.ExecuteBatch();
	Result = New Structure("ContractData, StagesOfPayment", QueryResult[2], QueryResult[3]);

	Return Not Result.StagesOfPayment.IsEmpty();
	
EndFunction

Function CalculatePaymentDate(Object, BasisRow, BaselineDate, LineNumber)
	
	TypeOfRef = TypeOf(Object.Ref);
	TextMessage = "";
	
	If (TypeOfRef = Type("DocumentRef.AccountSalesFromConsignee")
		Or TypeOfRef = Type("DocumentRef.AccountSalesToConsignor")) Then
		
		If BasisRow.PaymentTerm = Enums.PaymentTerm.PaymentInAdvance Then
			TextMessage = NStr("en = 'Fill-in payment in advance date manually in row number'; ru = 'Заполните дату аванса вручную в строку номер';pl = 'Wypełnij datę zaliczki ręcznie w numerze wiersza';es_ES = 'Rellenar la fecha de pago adelantado manualmente en el número de fila';es_CO = 'Rellenar la fecha de pago Anticipado manualmente en el número de fila';tr = 'Avans ödeme tarihini manuel olarak satır numarasına doldur';it = 'Compilare pagamento in data di anticipo manualmente nel numero di riga';de = 'Füllen Sie das Vorauszahlungsdatum mit Zeilennummern manuell aus'") + " " + LineNumber;
		EndIf;
		
	ElsIf TypeOfRef = Type("DocumentRef.AdditionalExpenses")
		And BasisRow.PaymentBaselineDate = Enums.BaselineDateForPayment.DocumentDate Then
		
		TextMessage = NStr("en = 'Fill-in date manually in row number'; ru = 'Заполните дату вручную в строку номер';pl = 'Wypełnij datę ręcznie w numerze wiersza';es_ES = 'Rellenar la fecha manualmente en el número de fila';es_CO = 'Rellenar la fecha manualmente en el número de fila';tr = 'Tarihi manuel olarak satır numarasına doldur';it = 'Compilare data manualmente nel numero di riga';de = 'Füllen Sie das Datum mit Zeilennummern manuell aus'") + " " + LineNumber;
	EndIf;
	
	If Not IsBlankString(TextMessage) Then
		
		CommonClientServer.MessageToUser(TextMessage, Object.Ref);
		
		Return Date(1,1,1);
		
	EndIf;
	
	ShiftedBaselineDate = BaselineDate;
	Multiplier = 1;
		
	If BasisRow.PaymentBaselineDate = Enums.BaselineDateForPayment.MonthEnd Then
		ShiftedBaselineDate = EndOfMonth(BaselineDate);
	ElsIf BasisRow.PaymentBaselineDate = Enums.BaselineDateForPayment.QuarterEnd Then
		ShiftedBaselineDate = EndOfQuarter(BaselineDate);
	ElsIf BasisRow.PaymentBaselineDate = Enums.BaselineDateForPayment.DocumentDate Then 
		Multiplier = -1;
	EndIf;

	Return ShiftedBaselineDate + Multiplier * BasisRow.PaymentDuePeriod * 86400;
		
EndFunction

Function CalculateBaselineDate(Object, AttributeName)
	
	Var Date;
	
	AttributesChain = New FixedArray(StringFunctionsClientServer.SplitStringIntoSubstringsArray(AttributeName, ".")); // AttributesChain array mustn't be modified	
	If Not SpecialBaselineDateCalculationRules(Object, Date)
		And DriveServer.AttributesChainExist(New Array(AttributesChain), Object) Then
		
		If AttributesChain.Count() > 1 Then
			OtherAttributes = Mid(AttributeName, StrFind(AttributeName, ".") + 1);
			Date = Common.ObjectAttributeValue(Object[AttributesChain[0]], OtherAttributes); 
		Else
			Date = Object[AttributeName];
		EndIf;
		
	EndIf;
	
	If Not ValueIsFilled(Date) Then
		If ValueIsFilled(Object.Date) Then
			Date = Object.Date;
		Else
			Date = CurrentSessionDate();
		EndIf;
	EndIf;
	
	Return Date;
	
EndFunction

Function SpecialBaselineDateCalculationRules(Object, Date)
	
	Var DateForCalculation;
	
	TypeOfRef = TypeOf(Object.Ref);
	
	If TypeOfRef = Type("DocumentRef.PurchaseOrder") 
		And Object.ReceiptDatePosition = Enums.AttributeStationing.InTabularSection Then
		
		DateForCalculation = "Inventory.ReceiptDate";
		
	ElsIf TypeOfRef = Type("DocumentRef.SalesOrder") 
		And Object.ShipmentDatePosition = Enums.AttributeStationing.InTabularSection Then
		
		DateForCalculation = "Inventory.ShipmentDate";
		
	Else
		Return False;
	EndIf;
	
	QueryText = 
	"SELECT
	|	CAST(&DateForCalculation AS DATE) AS Date
	|INTO TT_Inventory
	|FROM
	|	&Inventory AS Inventory
	|WHERE
	|	CAST(&DateForCalculation AS DATE) > DATETIME(1, 1, 1)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(TT_Inventory.Date) AS Date
	|FROM
	|	TT_Inventory AS TT_Inventory";
	
	Query = New Query();
	Query.Text = StrReplace(QueryText, "&DateForCalculation", DateForCalculation);
	Query.SetParameter("Inventory", Object.Inventory.Unload());
	
	QuerySelection = Query.Execute().Select();
	If QuerySelection.Next() Then
		
		Date = QuerySelection.Date;
		Return True;
		
	Else
		Return False;
	EndIf;
	
EndFunction

Function GetBaselineDatesForCalculation(Object, BasisDocument)
	
	BaselineDatesForCalculation = New Array;
	
	Filter = New Structure("Source, Receiver", TypeOf(BasisDocument), TypeOf(Object.Ref));
	
	InheritanceChains = GetInheritanceChains();
	For Each Chain In InheritanceChains.FindRows(Filter) Do
		BaselineDatesForCalculation.Add(Chain.BaselineDate);
	EndDo;
	
	Return BaselineDatesForCalculation;	
	
EndFunction

Function GetInheritanceChains()
	
	BaselineDatesForCalculation = New Array;
	
	BaselineDatesForCalculation.Add(Enums.BaselineDateForPayment.InvoicePostingDate);
	BaselineDatesForCalculation.Add(Enums.BaselineDateForPayment.MonthEnd);
	BaselineDatesForCalculation.Add(Enums.BaselineDateForPayment.QuarterEnd);
	
	InheritanceChains = New ValueTable;
	InheritanceChains.Columns.Add("Source");
	InheritanceChains.Columns.Add("Receiver");
	InheritanceChains.Columns.Add("BaselineDate");
	
	For Each BaselineDate In BaselineDatesForCalculation Do
		AddInheritanceChain(
			InheritanceChains, Type("DocumentRef.PurchaseOrder"), Type("DocumentRef.SupplierInvoice"), BaselineDate);
		AddInheritanceChain(
			InheritanceChains, Type("DocumentRef.SupplierInvoice"), Type("DocumentRef.AdditionalExpenses"), BaselineDate);
		AddInheritanceChain(
			InheritanceChains, Type("DocumentRef.SalesOrder"), Type("DocumentRef.SalesInvoice"), BaselineDate);
		AddInheritanceChain(
			InheritanceChains, Type("DocumentRef.WorkOrder"), Type("DocumentRef.SalesInvoice"), BaselineDate);
	EndDo;
		
	Return InheritanceChains; 	
	
EndFunction

Procedure AddInheritanceChain(InheritanceChains, Source, Receiver, BaselineDate)
	
	InheritanceRow = InheritanceChains.Add();
	InheritanceRow.Source = Source;
	InheritanceRow.Receiver = Receiver;
	InheritanceRow.BaselineDate = BaselineDate;
	
EndProcedure

Procedure SetPaymentTerms(Object)
	
	If Object.PaymentCalendar.Count() > 0 Then
		
		Object.SetPaymentTerms = True;
		
	ElsIf Object.SetPaymentTerms Then
		
		Totals = PaymentTermsClientServer.CalculateDocumentAmountVATAmountTotals(Object);
		
		NewRow = Object.PaymentCalendar.Add();
		
		NewRow.PaymentPercentage = 100;
		NewRow.PaymentAmount = Totals.Amount;
		NewRow.PaymentVATAmount = Totals.VATAmount;
		RefType = TypeOf(Object.Ref);
		NewRow.PaymentBaselineDate = GetDefaultPaymentBaselineDate(RefType);
		
		If NewRow.Property("CashFlowItem") Then
			If Object.Property("Contract") Then
				NewRow.CashFlowItem = Common.ObjectAttributeValue(Object.Contract, "CashFlowItem");
			EndIf;
			If Not ValueIsFilled(NewRow.CashFlowItem) Then
				NewRow.CashFlowItem = GetDefaultCashFlowItem(RefType);
			EndIf;
		EndIf;
		
	EndIf;
	
EndProcedure

Function GetDefaultPaymentBaselineDate(RefType)
	
	If RefType = Type("DocumentRef.AccountSalesFromConsignee") Then
		Return Enums.BaselineDateForPayment.InvoicePostingDate;
		
	ElsIf RefType = Type("DocumentRef.AccountSalesToConsignor") Then
		Return Enums.BaselineDateForPayment.PostingDate;
		
	ElsIf RefType = Type("DocumentRef.AdditionalExpenses") Then
		Return Enums.BaselineDateForPayment.InvoicePostingDate;
		
	ElsIf RefType = Type("DocumentRef.PurchaseOrder") Then
		Return Enums.BaselineDateForPayment.PostingDate;
		
	ElsIf RefType = Type("DocumentRef.Quote") Then
		Return Enums.BaselineDateForPayment.InvoicePostingDate;
		
	ElsIf RefType = Type("DocumentRef.SalesInvoice") Then
		Return Enums.BaselineDateForPayment.InvoicePostingDate;
		
	ElsIf RefType = Type("DocumentRef.SalesOrder") Then
		Return Enums.BaselineDateForPayment.PostingDate;
		
	ElsIf RefType = Type("DocumentRef.SubcontractorInvoiceReceived") Then
		Return Enums.BaselineDateForPayment.InvoicePostingDate;
	
	ElsIf RefType = Type("DocumentRef.SupplierInvoice") Then
		Return Enums.BaselineDateForPayment.InvoicePostingDate;
		
	ElsIf RefType = Type("DocumentRef.SupplierQuote") Then
		Return Enums.BaselineDateForPayment.InvoicePostingDate;
		
	ElsIf RefType = Type("DocumentRef.WorkOrder") Then
		Return Enums.BaselineDateForPayment.PostingDate;
		
	// begin Drive.FullVersion
	
	ElsIf RefType = Type("DocumentRef.SubcontractorInvoiceIssued") Then
		Return Enums.BaselineDateForPayment.InvoicePostingDate;
		
	ElsIf RefType = Type("DocumentRef.SubcontractorOrderReceived") Then
		Return Enums.BaselineDateForPayment.PostingDate;
		
	// end Drive.FullVersion 
	
	Else
		Return Enums.BaselineDateForPayment.EmptyRef();
	EndIf;
	
EndFunction

Function GetDefaultCashFlowItem(RefType)
	
	If RefType = Type("DocumentRef.AccountSalesFromConsignee") Then
		Return Catalogs.CashFlowItems.PaymentFromCustomers;
		
	ElsIf RefType = Type("DocumentRef.AccountSalesToConsignor") Then
		Return Catalogs.CashFlowItems.PaymentToVendor;
		
	ElsIf RefType = Type("DocumentRef.AdditionalExpenses") Then
		Return Catalogs.CashFlowItems.PaymentToVendor;
		
	ElsIf RefType = Type("DocumentRef.PurchaseOrder") Then
		Return Catalogs.CashFlowItems.PaymentToVendor;
		
	ElsIf RefType = Type("DocumentRef.Quote") Then
		Return Catalogs.CashFlowItems.PaymentFromCustomers;
		
	ElsIf RefType = Type("DocumentRef.SalesInvoice") Then
		Return Catalogs.CashFlowItems.PaymentFromCustomers;
		
	ElsIf RefType = Type("DocumentRef.SalesOrder") Then
		Return Catalogs.CashFlowItems.PaymentFromCustomers;
		
	ElsIf RefType = Type("DocumentRef.SubcontractorInvoiceReceived") Then
		Return Catalogs.CashFlowItems.PaymentToVendor;
	
	ElsIf RefType = Type("DocumentRef.SupplierInvoice") Then
		Return Catalogs.CashFlowItems.PaymentToVendor;
		
	ElsIf RefType = Type("DocumentRef.SupplierQuote") Then
		Return Catalogs.CashFlowItems.PaymentToVendor;
		
	ElsIf RefType = Type("DocumentRef.WorkOrder") Then
		Return Catalogs.CashFlowItems.PaymentFromCustomers;
		
	// begin Drive.FullVersion
	
	ElsIf RefType = Type("DocumentRef.SubcontractorInvoiceIssued") Then
		Return Catalogs.CashFlowItems.PaymentFromCustomers;
		
	ElsIf RefType = Type("DocumentRef.SubcontractorOrderReceived") Then
		Return Catalogs.CashFlowItems.PaymentFromCustomers;
		
	// end Drive.FullVersion 
	
	Else
		Return Catalogs.CashFlowItems.EmptyRef();
	EndIf;
	
EndFunction

Procedure FillPaymentCalendarWithoutSource(Object)
	
	SettingsStructure = New Structure;
	SettingsStructure.Insert("DocumentAmount", 0);
	SettingsStructure.Insert("DocumentTax", 0);
	SettingsStructure.Insert("AmountIncludesVAT", False);
	
	FillPropertyValues(SettingsStructure, Object);
	
	PaymentAmount = SettingsStructure.DocumentAmount 
		- ?(SettingsStructure.AmountIncludesVAT, 0, SettingsStructure.DocumentTax);
	
	NewLineStructure = New Structure;
	NewLineStructure.Insert("PaymentDate", Object.Date);
	NewLineStructure.Insert("PaymentPercentage", 100);
	NewLineStructure.Insert("PaymentAmount", PaymentAmount);
	NewLineStructure.Insert("PaymentVATAmount", SettingsStructure.DocumentTax);
	NewLineStructure.Insert("PaymentBaselineDate", Enums.BaselineDateForPayment.InvoicePostingDate);
	NewLineStructure.Insert("PaymentTerm", Enums.PaymentTerm.Net);
	
	FillPropertyValues(Object.PaymentCalendar.Add(), NewLineStructure);
	
EndProcedure

#EndRegion