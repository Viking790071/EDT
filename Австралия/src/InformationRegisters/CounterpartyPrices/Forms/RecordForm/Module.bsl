
&AtServerNoContext
// Receives the set of data from the server for the ProductsOnChange procedure.
//
Function GetDataProductsOnChange(Products)
	
	Return Products.MeasurementUnit;
	
EndFunction

#Region ProcedureFormEventHandlers

&AtClient
// Procedure - event handler BeforeClose form.
//
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	If RecordWasRecorded Then
		Notify("CounterpartyPriceChanged", RecordWasRecorded);
	EndIf;
	
EndProcedure

&AtServer
// Procedure - event handler BeforeWrite form.
//
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If Modified Then
		CurrentObject.Author = Users.CurrentUser();
	EndIf; 
	
EndProcedure

&AtClient
// Procedure - event handler AfterWrite form.
//
Procedure AfterWrite(WriteParameters)
	RecordWasRecorded = True;
EndProcedure

&AtServer
// Procedure - event handler OnCreateAtServer of the form.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	RecordWasRecorded = False;
	
	If Not ValueIsFilled(Record.SourceRecordKey.SupplierPriceTypes) Then
		
		Record.Author = Users.CurrentUser();
		
		If Parameters.FillingValues.Property("Counterparty") AND ValueIsFilled(Parameters.FillingValues.Counterparty) Then
			Record.Counterparty = Parameters.FillingValues.Counterparty;
		EndIf;                                                       
		
		If Parameters.Property("Counterparty") AND ValueIsFilled(Parameters.Counterparty) Then
			Record.Counterparty = Parameters.Counterparty;	
		EndIf;
		
		If NOT ValueIsFilled(Record.Counterparty) AND ValueIsFilled(Record.SupplierPriceTypes) Then
			Record.Counterparty = Record.SupplierPriceTypes.Counterparty;
		EndIf;
		
		If Parameters.FillingValues.Property("Products") AND ValueIsFilled(Parameters.FillingValues.Products) Then
			Record.MeasurementUnit = Parameters.FillingValues.Products.MeasurementUnit;	
		EndIf;
		
	EndIf;
	
	SettingValue = DriveReUse.GetValueByDefaultUser(Users.CurrentUser(), "MainCompany");
	If ValueIsFilled(SettingValue) Then
		Company = SettingValue;
	Else
		Company = Catalogs.Companies.MainCompany;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	// Prices precision begin
	PrecisionAppearanceClient.SetPricesAppearance(ThisObject, Company, PricesFields());
	// Prices precision end
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the Products input field.
//
Procedure ProductsOnChange(Item)
	
	Record.MeasurementUnit = GetDataProductsOnChange(Record.Products);
	
EndProcedure

&AtClient
// Procedure - event handler StartChoice input field PriceKind.
//
Procedure PriceTypestartChoice(Item, ChoiceData, StandardProcessing)
	
	If Not ValueIsFilled(Record.Counterparty) Then
		
		StandardProcessing = False;
		MessageText = NStr("en = 'Specify the counterparty to select the price type.'; ru = 'Укажите контрагента для выбора типа цен.';pl = 'Wybierz kontrahenta aby wybrać rodzaj ceny.';es_ES = 'Especifique la contraparte para seleccionar el tipo de precio.';es_CO = 'Especifique la contraparte para seleccionar el tipo de precio.';tr = 'Fiyat türünü seçmek için cari hesabı belirtin.';it = 'Specificare la controparte per selezionare il tipo di prezzo.';de = 'Geben Sie den Geschäftspartner an, um den Preistyp auszuwählen.'");
		CommonClientServer.MessageToUser(MessageText, , , "Counterparty");
		
	Else 
		
		StandardProcessing = False;
	    OpenForm("Catalog.SupplierPriceTypes.ChoiceForm", New Structure("Counterparty", Record.Counterparty), Item);
		
	EndIf;
	
EndProcedure

&AtClient
Function PricesFields()
	
	Fields = New Array();
	Fields.Add(Items.Price);
	
	Return Fields;
	
EndFunction

#EndRegion
