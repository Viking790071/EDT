
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// StandardSubsystems.ObjectAttributesLock
	ObjectAttributesLock.LockAttributes(ThisObject);
	// End StandardSubsystems.ObjectAttributesLock
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject, Object);
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)

	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)

	NativeLanguagesSupportServer.BeforeWriteAtServer(CurrentObject);
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)

	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure Attachable_Open(Item, StandardProcessing)
	NativeLanguagesSupportClient.OnOpen(ThisObject, Object, Item, StandardProcessing);
EndProcedure

#EndRegion

#Region Private

#Region LibrariesHandlers

// StandardSubsystems.ObjectAttributesLock

&AtClient
Procedure Attachable_AllowObjectAttributesEditing(Command)
	If ThisObject.Object.Predefined Then
		ShowMessageBox(, NStr("en = 'Sorry, it is prohibited to change attributes for predefined elements.'; ru = 'Изменение реквизитов предустановленных элементов запрещено.';pl = 'Przepraszamy, zmiana atrybutów dla predefiniowanych elementów jest zabroniona.';es_ES = 'Lo sentimos, está prohibido modificar los atributos de los elementos predefinidos.';es_CO = 'Lo sentimos, está prohibido modificar los atributos de los elementos predefinidos.';tr = 'Maalesef, önceden tanımlanmış ögelerin özniteliklerini değiştirmeye izin verilmemektedir.';it = 'Siamo spiacenti, è vietato modificare attributi di un elemento predefinito.';de = 'Es ist leider verboten, Attribute für vorgegebene Elemente zu ändern.'"));
		Return;
	EndIf;
	ObjectAttributesLockClient.AllowObjectAttributeEdit(ThisObject);
EndProcedure

// End StandardSubsystems.ObjectAttributesLock

#EndRegion

#EndRegion