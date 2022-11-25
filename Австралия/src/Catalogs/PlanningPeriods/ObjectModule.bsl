#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

// Procedure - event handler FillCheckProcessing object.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If (NOT IsFolder) AND ValueIsFilled(StartDate)
		AND ValueIsFilled(EndDate) Then
		
		If StartDate > EndDate Then
			
			Message = New UserMessage;
			Message.Text = NStr("en = 'The Start date field value is greater than the End date field value.'; ru = 'Значение поля ""Дата начала"" больше значения поля ""Дата окончания""';pl = 'Wartość pola Data rozpoczęcia jest większa niż wartość pola Data zakończenia.';es_ES = 'El valor del campo de la fecha Inicial es mayor al valor del campo de la fecha Final.';es_CO = 'El valor del campo de la fecha Inicial es mayor al valor del campo de la fecha Final.';tr = 'Başlangıç tarihi alanındaki değer Bitiş tarihi alanındaki değerden ileri.';it = 'Il valore del campo Data di inizio è maggiore del valore del campo Data di fine.';de = 'Der Feldwert Startdatum ist größer als der Feldwert Enddatum.'");
			Message.Field = "Object.StartDate";
			Message.Message();
			
			Cancel = True;
			
		EndIf;
		
	EndIf;
	
	If (NOT IsFolder) AND (Ref = Catalogs.PlanningPeriods.Actual) Then
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "StartDate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "EndDate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Periodicity");
		
	EndIf;
	
EndProcedure

#EndRegion

#EndIf