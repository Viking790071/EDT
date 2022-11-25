#Region FormEventHandlers

&AtServer
// Procedure - event handler OnCreateAtServer of the form.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	RecordWasRecorded = False;
	
	If Not ValueIsFilled(Record.SourceRecordKey.PriceKind) Then
		
		Record.Author = Users.CurrentUser();
		
		If Parameters.Property("FillingValues") 
			AND TypeOf(Parameters.FillingValues) = Type("Structure")
			AND Parameters.FillingValues.Property("Products")
			AND ValueIsFilled(Parameters.FillingValues.Products) Then
			
			Record.MeasurementUnit = Parameters.FillingValues.Products.MeasurementUnit;
			
		EndIf;
		
	EndIf;
	
	If Parameters.Property("PriceKind")
		And ValueIsFilled(Parameters.PriceKind) Then
		
		Record.PriceKind = Parameters.PriceKind;
		
	EndIf;
	
	If Not ValueIsFilled(Record.PriceKind) Then
		
		Record.PriceKind = Catalogs.PriceTypes.GetMainKindOfSalePrices();
		
	EndIf;
	
	If Parameters.Property("Products")
		And ValueIsFilled(Parameters.Products) Then
		
		Record.Products = Parameters.Products;
		Record.MeasurementUnit = Common.ObjectAttributeValue(Parameters.Products, "MeasurementUnit");
		
	EndIf;
	
	If Parameters.Property("Price") Then
		
		Record.Price = Parameters.Price;
		
	EndIf;
	
	// Price accessibility setup for editing.
	AllowedEditDocumentPrices = DriveAccessManagementReUse.AllowedEditDocumentPrices();
	
	ReadOnly = Not AllowedEditDocumentPrices;
	
	SettingValue = DriveReUse.GetValueByDefaultUser(Users.CurrentUser(), "MainCompany");
	If ValueIsFilled(SettingValue) Then
		Company = SettingValue;
	Else
		Company = Catalogs.Companies.MainCompany;
	EndIf;
	
EndProcedure

&AtClient
// Procedure - event handler BeforeClose form.
//
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	If RecordWasRecorded Then
		Notify("PriceChanged", RecordWasRecorded);
	EndIf;
	
EndProcedure

&AtServer
// Procedure - event handler BeforeWrite form.
//
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If CurrentObject.PriceKind.CalculatesDynamically Then
		
		MessageText = NStr("en = 'Сannot save data with dynamic price types.'; ru = 'Не удалось записать данные с динамическими типами цен.';pl = 'Nie można zapisać danych z dynamicznymi rodzajami cen.';es_ES = 'No puede guardar los datos con los tipos dinámicos del precio.';es_CO = 'No puede guardar los datos con los tipos dinámicos del precio.';tr = 'Dinamik fiyat türleriyle veriler kaydedilemez.';it = 'Impossibile salvare i dati con tipi di prezzo dinamici.';de = 'Fehler beim Speichern von Daten mit dynamischen Preistypen.'");
		CommonClientServer.MessageToUser(MessageText, ,"Record.PriceKind", , Cancel);
		
	EndIf;
	
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

&AtClient
Procedure OnOpen(Cancel)
	
	// Prices precision begin
	PrecisionAppearanceClient.SetPricesAppearance(ThisObject, Company, PricesFields());
	// Prices precision end
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
// Procedure - event handler OnChange of the Products input field.
//
Procedure ProductsOnChange(Item)
	
	Record.MeasurementUnit = GetDataProductsOnChange(Record.Products);
	
EndProcedure

#EndRegion

#Region Private

&AtServerNoContext
// Receives the set of data from the server for the ProductsOnChange procedure.
//
Function GetDataProductsOnChange(Products)
	
	Return Products.MeasurementUnit;
	
EndFunction

&AtClient
Function PricesFields()
	
	Fields = New Array();
	Fields.Add(Items.Price);
	
	Return Fields;
	
EndFunction

#EndRegion
