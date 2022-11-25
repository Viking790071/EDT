#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure BeforeWrite(Cancel)
	If DataExchange.Load Or AdditionalProperties.Property("DoNotCheckUniqueness") Then
		Return;
	EndIf;
	
	If Not CheckFilling() Then
		Cancel = True;
	EndIf;
EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	Existing = ExistingItem();
	If Existing<>Undefined Then
		Cancel = True;
		CommonClientServer.MessageToUser(Existing.ErrorDescription,, "Object.Description");
	EndIf;
	
EndProcedure

Procedure Filling(FillingData, FillingText, StandardProcessing)
	If FillingData<>Undefined Then
		FillPropertyValues(ThisObject, FillingData);
	EndIf;
EndProcedure

#EndRegion

#Region Private

// Controls item uniqueness in the infobase.
//
//  Returns:
//      Undefined - no errors.
//      Structure - infobase item details. Properties:
//          * ErrorDescription     - String - an error text.
//          * Code                - String - an attribute of an existing item.
//          * Description       - String - an attribute of an existing item.
//          * FullDescription - String - an attribute of an existing item.
//          * CodeAlpha2          - String - an attribute of an existing item.
//          * CodeAlpha3          - String - an attribute of an existing item.
//          * Reference             - CatalogRef.WorldCountries - an attribute of an existing item.
//
Function ExistingItem()
	
	Result = Undefined;
	
	// Skip non-numerical codes
	NumberType = New TypeDescription("Number", New NumberQualifiers(3, 0, AllowedSign.Nonnegative));
	If Code="0" Or Code="00" Or Code="000" Then
		SearchCode = "000";
	Else
		SearchCode = Format(NumberType.AdjustValue(Code), "ND=3; NFD=2; NZ=; NLZ=");
		If SearchCode="000" Then
			Return Result; // Not a number
		EndIf;
	EndIf;
		
	Query = New Query("
		|SELECT TOP 1
		|	Code                AS Code,
		|	Description       AS Description,
		|	DescriptionFull AS DescriptionFull,
		|	CodeAlpha2          AS CodeAlpha2,
		|	CodeAlpha3          AS CodeAlpha3,
		|	EEUMember       AS EEUMember,
		|	Ref             AS Ref
		|FROM
		|	Catalog.WorldCountries
		|WHERE
		|	Code=&Code 
		|	AND Ref <> &Ref
		|");
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("Code",    SearchCode);
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	If Selection.Next() Then
		Result = New Structure("ErrorDescription", 
			StringFunctionsClientServer.SubstituteParametersToString(NStr("ru='С кодом %1 уже существует страна %2. Измените код или используйте уже существующие данные.'; en = 'Country %2 with code %1 already exists. Change the code, or use the existing data.'; pl = 'Kod %1jest już przypisany do kraju %2. Wprowadź inny kod lub użyj istniejących danych.';es_ES = 'Código %1 ya está asignado al país %2. Introducir otro código, o utilizar los datos existentes.';es_CO = 'Código %1 ya está asignado al país %2. Introducir otro código, o utilizar los datos existentes.';tr = '%1 kodlu %2 ülkesi zaten var. Kodu değiştirin veya varolan verileri kullanın.';it = 'Il paese %2 con codice %1 esiste già. Modificare il codice o utilizzare i dati esistenti.';de = 'Der Code %1 ist bereits dem Land zugewiesen%2. Geben Sie einen anderen Code ein oder verwenden Sie die vorhandenen Daten.'"),
			Code, Selection.Description));
		
		For Each Field In QueryResult.Columns Do
			Result.Insert(Field.Name, Selection[Field.Name]);
		EndDo;
	EndIf;
	
	Return Result;
EndFunction

#EndRegion

#EndIf
