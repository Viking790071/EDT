#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

Function CheckStagesOfPayment(Object) Export
	
	Cancel = False;
	
	NumberOfStages = Object.StagesOfPayment.Count();
	For CurrentIndex = 0 To NumberOfStages - 1 Do
		
		CurrentLine = Object.StagesOfPayment[CurrentIndex];
		
		ErrorAddress = " " + NStr("en = 'in line %1 the Payment terms tab'; ru = 'в строке %1 вкладки Условия оплаты';pl = 'w wierszu %1 karty Warunki płatności';es_ES = 'en la línea %1 la pestaña de los términos de Pago';es_CO = 'en la línea %1 la pestaña de los términos de Pago';tr = '%1 satırında Ödeme şartları sekmesi';it = 'nella linea %1 la scheda termini di Pagamento ';de = 'in der Zeile %1 der Registerkarte Zahlungsbedingungen'");
		
		ErrorAddress = StrReplace(ErrorAddress, "%1", CurrentLine.LineNumber);
		
		If Not ValueIsFilled(CurrentLine.Term) Then
			
			ErrorText = NStr("en = 'Column ""Term"" is empty'; ru = 'Не заполнена колонка ""Срок оплаты""';pl = 'Kolumna ""Termin"" jest pusta';es_ES = 'Columna ""Término"" está vacía';es_CO = 'Columna ""Término"" está vacía';tr = '""Koşul"" sütunu boş';it = 'La colonna ""Termini"" è vuota';de = 'Die Spalte ""Begriff"" ist leer'");
				PathToTabularSection = CommonClientServer.PathToTabularSection(
				"Object.StagesOfPayment",
				CurrentLine.LineNumber,
				"Term");
			
			CommonClientServer.MessageToUser(
				ErrorText + ErrorAddress,
				,
				PathToTabularSection,
				,
				Cancel);
			
		EndIf;
		
		If Not ValueIsFilled(CurrentLine.BaselineDate) Then
			
			ErrorText = NStr("en = 'Column ""Baseline date"" is empty'; ru = 'Не заполнена колонка ""Базисная дата""';pl = 'Kolumna ""Data bazowa"" jest pusta';es_ES = 'Columna ""Fecha de referencia"" está vacía';es_CO = 'Columna ""Fecha de referencia"" está vacía';tr = '""Başlangıç tarihi"" sütunu boş';it = 'La colonna ""Data di base"" è vuota';de = 'Die Spalte ""Basisdatum"" ist leer'");
			PathToTabularSection = CommonClientServer.PathToTabularSection(
				"Object.StagesOfPayment",
				CurrentLine.LineNumber,
				"BaselineDate");
			
			CommonClientServer.MessageToUser(
				ErrorText + ErrorAddress,
				,
				PathToTabularSection,
				,
				Cancel);
			
		EndIf;
		
		If Not ValueIsFilled(CurrentLine.PaymentPercentage) Then
			
			ErrorText = NStr("en = 'Column ""% of payment"" is empty'; ru = 'Не заполнена колонка ""% оплаты""';pl = 'Kolumna ""% płatności"" jest pusta';es_ES = 'Columna ""% de pago"" está vacía';es_CO = 'Columna ""% de pago"" está vacía';tr = '""ödemenin %''si"" sütunu boş';it = 'La colonna ""% di pagamento"" è vuota';de = 'Die Spalte ""% der Zahlung"" ist leer'");
				PathToTabularSection = CommonClientServer.PathToTabularSection(
				"Object.StagesOfPayment",
				CurrentLine.LineNumber,
				"PaymentPercentage");
			
			CommonClientServer.MessageToUser(
				ErrorText + ErrorAddress,
				,
				PathToTabularSection,
				,
				Cancel);
			
		EndIf;
		
	EndDo;
	
	If NumberOfStages > 0 And Object.StagesOfPayment.Total("PaymentPercentage") <> 100 Then
		ErrorText = NStr("en = 'Percetange amount in the Payment terms tab should be equal to 100%'; ru = 'На вкладке ""Условия оплаты"" некорректно указаны проценты. Сумма должна быть равна 100%';pl = 'Wartość procentów na karcie Warunki płatności musi być równa 100%';es_ES = 'Por ciento del importe en la pestaña de los términos de Pago tiene que ser igual a 100%';es_CO = 'Por ciento del importe en la pestaña de los términos de Pago tiene que ser igual a 100%';tr = 'Ödeme şartları sekmesindeki yüzdelik tutar % 100''e eşit olmalıdır';it = 'L''importo percentuale nella scheda scheda Termini di pagamento deve essere uguale al 100%';de = 'Der Prozentsatz auf der Registerkarte Zahlungsbedingungen sollte 100% betragen.'");
		CommonClientServer.MessageToUser(ErrorText, , "PaymentPercentage", , Cancel);
		Return Not Cancel;
	EndIf;
	
	CheckStagesOfPaymentFollowingOrder(Object, Cancel);
	
	Return Not Cancel;
	
EndFunction

#EndRegion

#Region EventHandlers

Procedure ChoiceDataGetProcessing(ChoiceData, Parameters, StandardProcessing)
	
	NativeLanguagesSupportServer.ChoiceDataGetProcessing(
		ChoiceData,
		Parameters,
		StandardProcessing,
		Metadata.Catalogs.PaymentTermsTemplates);
	
EndProcedure

Procedure PresentationGetProcessing(Data, Presentation, StandardProcessing)
	
	NationalLanguageSupportClientServer.PresentationGetProcessing(Data, Presentation, StandardProcessing);
	
EndProcedure

Procedure PresentationFieldsGetProcessing(Fields, StandardProcessing)
	
	NationalLanguageSupportClientServer.PresentationFieldsGetProcessing(Fields, StandardProcessing);
	
EndProcedure

#EndRegion

#Region Private

Procedure CheckStagesOfPaymentFollowingOrder(Object, Cancel)
	
	Var DataSelection, ErrorText, PathToTabularSection, PreviousDuePeriodValue, PreviousTermOrderValue, PreviousTermValue, Query, TextMessage;
	
	Query = New Query("
	|SELECT
	|	Stages.LineNumber AS LineNumber,
	|	Stages.DuePeriod AS DuePeriodValue,
	|	Stages.Term AS TermValue
	|INTO TempStages
	|FROM
	|	&StagesOfPayment AS Stages
	|;
	|
	|////////////////////////////////////////////
	|SELECT
	|	Table.LineNumber AS LineNumber,
	|	Table.DuePeriodValue AS DuePeriodValue,
	|	Table.TermValue AS TermValue,
	|	CASE WHEN Table.TermValue = VALUE(Enum.PaymentTerm.EmptyRef)
	|		THEN 0
	|		ELSE Table.TermValue.Order
	|	END AS TermOrderValue
	|FROM
	|	TempStages AS Table
	|
	|ORDER BY
	|	LineNumber");
	
	Query.SetParameter("StagesOfPayment", Object.StagesOfPayment.Unload());
	
	DataSelection = Query.Execute().Select();
	
	PreviousTermOrderValue = 0;
	PreviousDuePeriodValue = 0;
	PreviousTermValue = Undefined;
	
	While DataSelection.Next() Do
		
		If PreviousTermOrderValue > DataSelection.TermOrderValue Then
			
			ErrorText = NStr("en = 'The term %1 in line %2 can''t follow the term %3 in line %4'; ru = 'Вариант оплаты %1 в строке %2 не может идти после варианта %3 в строке %4';pl = 'Termin %1 w wierszu %2 nie może być późniejszy niż termin %3 w wierszu %4';es_ES = 'El término %1 en la línea %2 no puede seguir el término %3 en la línea %4';es_CO = 'El término %1 en la línea %2 no puede seguir el término %3 en la línea %4';tr = '%2 satırındaki %1 terimi %4 satırındaki %3 terimini takip edemez';it = 'Il termine %1 nella linea %2 non può seguire il termine %3 nella linea %4';de = 'Der Frist %1 der Zeile %2 kann nicht der Frist %3 in der Zeile %4 folgen.'");
			
			TextMessage = StringFunctionsClientServer.SubstituteParametersToString(ErrorText,
				DataSelection.TermValue,
				DataSelection.LineNumber,
				PreviousTermValue,
				DataSelection.LineNumber - 1);
			
			PathToTabularSection = "Object." + CommonClientServer.PathToTabularSection(
				"Object.StagesOfPayment",
				DataSelection.LineNumber,
				"Term");
			
			CommonClientServer.MessageToUser(
				TextMessage,
				,
				PathToTabularSection,
				,
				Cancel);
			
		EndIf;
			
		If DataSelection.TermValue = Enums.PaymentTerm.Net // Current stage is Net
			AND DataSelection.TermOrderValue <> PreviousTermOrderValue Then // And previous stage isn't Net
			PreviousDuePeriodValue = 0;
		EndIf;
		
		PreviousTermOrderValue = DataSelection.TermOrderValue;
		PreviousTermValue = DataSelection.TermValue;
		
	EndDo;

EndProcedure

#EndRegion

#EndIf
