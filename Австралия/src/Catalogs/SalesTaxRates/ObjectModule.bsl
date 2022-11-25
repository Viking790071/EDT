#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If NOT Combined AND TaxComponents.Count() > 0 Then
		TaxComponents.Clear();
	ElsIf Combined AND ValueIsFilled(Agency) Then
		Agency = Catalogs.TaxTypes.EmptyRef();
	EndIf;
	
EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If Combined AND TaxComponents.Count() = 0 Then
		
		MessageText = NStr("en = 'The combined sales tax rate must have its components filled in.'; ru = 'Необходимо заполнить все компоненты комбинированной ставки налога с продаж.';pl = 'Należy wypełnić elementy stawki podatku od sprzedaży.';es_ES = 'La tasa de impuesto sobre ventas combinada debe tener sus componentes rellenados.';es_CO = 'La tasa de impuesto sobre ventas combinada debe tener sus componentes rellenados.';tr = 'Birleştirilmiş satış vergisi oranının bileşenleri doldurulmalı.';it = 'L''aliquota fiscale combinata di vendita deve avere le proprie componenti compilate.';de = 'Der Materialbestand des kombinierten Umsatzsteuersatzes soll ausgefüllt werden.'");
		
		DriveServer.ShowMessageAboutError(ThisObject, MessageText,,, "Combined", Cancel);
		
	EndIf;
	
EndProcedure

#EndRegion

#EndIf