#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

// Procedure performs the device parameter initialization.
//
Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If IsNew() Then
		Parameters = New ValueStorage(New Structure());
	EndIf;
	
EndProcedure

// Procedure checks the catalog
// item description uniqueness for this computer.
Procedure FillCheckProcessing(Cancel, CheckedAttributes)

	If Not IsBlankString(Description) Then
		Query = New Query("
		|SELECT
		|    1
		|FROM
		|    Catalog.Peripherals AS Peripherals
		|WHERE
		|    Peripherals.Description = &Description
		|    AND Peripherals.Workplace = &Workplace
		|    AND Peripherals.Ref <> &Ref
		|");

		Query.SetParameter("Description", Description);
		Query.SetParameter("Workplace", Workplace);
		Query.SetParameter("Ref"      , Ref);

		If Not Query.Execute().IsEmpty() Then
			CommonClientServer.MessageToUser(NStr("en = 'Non-unique item name specified. Specify a unique name.'; ru = 'Указано неуникальное наименование элемента. Укажите уникальное наименование.';pl = 'Podano nie unikalną nazwę przedmiotu. Podaj unikalną nazwę.';es_ES = 'Nombre del artículo no único especificado. Especificar un nombre único.';es_CO = 'Nombre del artículo no único especificado. Especificar un nombre único.';tr = 'Benzersiz olmayan öğe adı belirtildi. Benzersiz bir ad belirtin.';it = 'Nome dell''elemento non univoco specificato. Specificare un nome univoco.';de = 'Nicht eindeutiger Elementname angegeben. Geben Sie einen eindeutigen Namen an.'"), ThisObject, , , Cancel);
		EndIf;
	EndIf;

EndProcedure

// Procedure performs attribute cleaning which shouldn't be copied.
// The following attributes are cleared when you copy:
// "Parameters"    - device parameters are reset to Undefined;
// "Description"   - other than the original description is set;
Procedure OnCopy(CopiedObject)
	
	DeviceIsInUse = True;
	Parameters = Undefined;

	Description = NStr("en = '%Description% (copy)'; ru = '%Description% (копия)';pl = '%Description% (kopiuj)';es_ES = '%Description% (copia)';es_CO = '%Description% (copia)';tr = '%Description% (kopya)';it = '%Description% (copia)';de = '%Description% (Kopie)'");
	Description = StrReplace(Description, "%Description%", CopiedObject.Description);
	
EndProcedure

// On write
//
Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;

EndProcedure

#EndRegion

#EndIf