
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Counterparty = Parameters.Counterparty;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	FormManagement();
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure DeliveryOptionOnChange(Item)
	
	FormManagement();
	
EndProcedure

&AtClient
Procedure ShippingAddressOnChange(Item)
	
	If ValueIsFilled(ShippingAddress) Then
		FillInContactPerson();
	Else
		ContactPerson = Undefined;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure OK(Command)
	
	If ShipmentDate = Date(1,1,1) Then
		CommonClientServer.MessageToUser(NStr("en = 'Shipment date is required.'; ru = 'Не указана дата отгрузки.';pl = 'Wymagana jest data wysyłki.';es_ES = 'Se requiere una fecha de envío.';es_CO = 'Se requiere una fecha de envío.';tr = 'Sevkiyat tarihi gerekli.';it = 'È richiesta la data di spedizione.';de = 'Lieferdatum ist erforderlich'"));
		Return;
	EndIf;
	
	Result = New Structure;
	
	Result.Insert("ContactPerson", ContactPerson);
	Result.Insert("DeliveryOption", DeliveryOption);
	Result.Insert("ShipmentDate", ShipmentDate);
	Result.Insert("ShippingAddress", ShippingAddress);
	
	Close(Result);
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure FormManagement()
	
	Delivery = (DeliveryOption = PredefinedValue("Enum.DeliveryOptions.Delivery"));
	CommonClientServer.SetFormItemProperty(Items, "ShippingAddress", "Visible", Delivery);
	CommonClientServer.SetFormItemProperty(Items, "ContactPerson", "Visible", Delivery);
	
EndProcedure

&AtServer
Procedure FillInContactPerson()
	
	DeliveryData = ShippingAddressesServer.GetDeliveryAttributesForAddress(ShippingAddress);
	ContactPerson = DeliveryData.ContactPerson;
	
EndProcedure

#EndRegion