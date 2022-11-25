#Region Public

#Region ShippingAddressData

// Gets structure with Shipping address and Delivery option of Counterparty
//
// Parameters:
//  Counterparty - CatalogRef.Counterparties
//
Function GetDeliveryDataForCounterparty(Counterparty, GetDeliveryOption = True) Export
	
	StructureData = New Structure();
	
	ShippingAddressByDefault = Catalogs.ShippingAddresses.GetDefaultShippingAddress(Counterparty);
	
	StructureData.Insert("ShippingAddress", ShippingAddressByDefault);
	If GetDeliveryOption And ValueIsFilled(Counterparty) Then
		StructureData.Insert("DeliveryOption", Common.ObjectAttributeValue(Counterparty, "DefaultDeliveryOption"));
	Else
		StructureData.Insert("DeliveryOption", Enums.DeliveryOptions.EmptyRef());
	EndIf;
	
	Return StructureData;
	
EndFunction

// Gets structure with attributes of shipping address
//
// Parameters:
//  ShippingAddress - CatalogRef.Counterparties, CatalogRef.ShippingAdresses
//
// Returns:
//  Structure - attribute values of the shipping address
Function GetDeliveryAttributesForAddress(ShippingAddress) Export
	
	StructureData = New Structure;
	StructureData.Insert("Incoterms", Catalogs.Incoterms.EmptyRef());
	StructureData.Insert("ContactPerson", Catalogs.ContactPersons.EmptyRef());
	StructureData.Insert("DeliveryTimeFrom", Date(1,1,1));
	StructureData.Insert("DeliveryTimeTo", Date(1,1,1));
	StructureData.Insert("SalesRep", Catalogs.Employees.EmptyRef());
	
	If ShippingAddress <> Undefined And ValueIsFilled(ShippingAddress) Then
		
		If TypeOf(ShippingAddress) = Type("CatalogRef.ShippingAddresses") Then
			
			FillPropertyValues(StructureData, ShippingAddress);
			
		EndIf;
		
	EndIf;
	
	Return StructureData;
	
EndFunction

// Sets Shipping address as default
//
// Parameters:
//  ParametersStructure - Structure - structure with owner and new default shipping address
//    Counterparty - CatalogRef.Counterparties - counterparty - owner of addresses
//    NewDefaultShippingAddresses - CatalogRef.ShippingAddresses - new default shipping address
//
Procedure SetShippingAddressAsDefault(ParametersStructure) Export
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	ShippingAddresses.Ref AS Ref
	|FROM
	|	Catalog.ShippingAddresses AS ShippingAddresses
	|WHERE
	|	ShippingAddresses.Owner = &Owner
	|	AND ShippingAddresses.IsDefault";
	
	Query.SetParameter("Owner", ParametersStructure.Counterparty);
	
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then 
		
		ResultTable = Undefined;
		
	Else
		
		ResultTable = QueryResult.Unload();
		
		If ResultTable[0].Ref = ParametersStructure.NewDefaultShippingAddresses Then
			Return;
		EndIf;
		
	EndIf;
	
	BeginTransaction();
	
	Try
		
		If Not ResultTable = Undefined Then
		
			OldShippingAddresseObject = ResultTable[0].Ref.GetObject();
			OldShippingAddresseObject.IsDefault = False;
			OldShippingAddresseObject.Write();
		
		EndIf;
		
		NewShippingAddresseObject = ParametersStructure.NewDefaultShippingAddresses.GetObject();
		NewShippingAddresseObject.IsDefault = True;
		NewShippingAddresseObject.Write();

		CommitTransaction();
		
	Except
		
		RollbackTransaction();
		
		CommonClientServer.MessageToUser(NStr("en = 'Failed to set default shipping address'; ru = 'Не удалось установить адрес доставки по умолчанию';pl = 'Nie udało się ustawić domyślnego adresu wysyłki';es_ES = 'Fallado a establecer la dirección de envío por defecto';es_CO = 'Fallado a establecer la dirección de envío por defecto';tr = 'Varsayılan gönderim adresi ayarlanamadı';it = 'Non riuscito ad impostare l''indirizzo di consegna predefinito';de = 'Standard-Versandadresse konnte nicht festgelegt werden'"));
		
	EndTry;
	
EndProcedure

#EndRegion

#EndRegion
