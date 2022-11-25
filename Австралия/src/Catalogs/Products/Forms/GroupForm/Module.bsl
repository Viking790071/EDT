
#Region FormEventHandlers

&AtClient
Procedure AfterWrite(WriteParameters)
	Notify("Write_ProductsGroup", Object.Ref);
EndProcedure

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AdditionalParameters")
		And Parameters.AdditionalParameters.Property("Parent") Then
		
		Object.Parent = Parameters.AdditionalParameters.Parent;
		
	EndIf;
	
	If Object.Ref.IsEmpty() Then
		
		AutoTitle = False;
		
		Title = NStr("en = 'Products (Create group)'; ru = 'Номенклатура (создать группу)';pl = 'Produkty (Utwórz grupę)';es_ES = 'Productos (Crear grupo)';es_CO = 'Productos (Crear grupo)';tr = 'Ürünler (Grup oluştur)';it = 'Articoli (Crea gruppo)';de = 'Produkte (Gruppe erstellen)'");
		
	EndIf;
	
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
	
	If Not AutoTitle Then
	
		AutoTitle = True;
		
		Title = "";
	
	EndIf; 
	
	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure Attachable_Open(Item, StandardProcessing)
	NativeLanguagesSupportClient.OnOpen(ThisObject, Object, Item, StandardProcessing);
EndProcedure

#EndRegion
