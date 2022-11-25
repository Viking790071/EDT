
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If ValueIsFilled(Object.Ref) Then
		ColorAttribute = Common.ObjectAttributeValue(Object.Ref, "Color");
		If ValueIsFilled(ColorAttribute) Then
			Color = ColorAttribute.Get();
		EndIf;
		If Object.Ref = DriveReUse.GetValueOfSetting("StatusOfNewSubcontractorOrderReceived") Then
			Items.FormCommandSetMainItem.Title = NStr("en = 'Used to create new orders'; ru = 'Используется для создания новых заказов';pl = 'Służy do tworzenia nowych zamówień';es_ES = 'Solía crear nuevas órdenes';es_CO = 'Solía crear nuevas órdenes';tr = 'Yeni siparişler oluşturmak için kullanılır';it = 'Utilizzato per creare nuovi ordini';de = 'Wird verwendet, um neue Aufträge zu erstellen'");
			Items.FormCommandSetMainItem.Enabled = False;
		EndIf;
	Else
		CopyingValue = Undefined;
		Parameters.Property("CopyingValue", CopyingValue);
		If CopyingValue <> Undefined Then
			Color = CopyingValue.Color.Get();
		Else
			Color = StyleColors.ToolTipTextColor;
		EndIf;
	EndIf;
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject, Object);
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If Color = StyleColors.ToolTipTextColor Then
		CurrentObject.Color = New ValueStorage(Undefined);
	Else
		CurrentObject.Color = New ValueStorage(Color);
	EndIf;
	
	NativeLanguagesSupportServer.BeforeWriteAtServer(CurrentObject);
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	Notify("Write_SubcontractorOrderReceivedStatuses");
	
EndProcedure 

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
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

#Region FormCommandsEventHandlers

&AtClient
Procedure CommandSetMainItem(Command)
	
	If ValueIsFilled(Object.Ref) Then
		SetMainItem();
		Notify("UserSettingsChanged");
	Else
		ShowMessageBox(Undefined, NStr("en = 'Save the item first.'; ru = 'Сначала запишите элемент.';pl = 'Najpierw zapisz element.';es_ES = 'Guardar primero el artículo.';es_CO = 'Guardar primero el artículo.';tr = 'Önce öğeyi kaydedin.';it = 'Salvare prima l''elemento.';de = 'Speichern Sie den Artikel zuerst.'"));
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetMainItem()
	
	If Object.Ref <> DriveReUse.GetValueOfSetting("StatusOfNewSubcontractorOrderReceived") Then
		DriveServer.SetUserSetting(Object.Ref, "StatusOfNewSubcontractorOrderReceived");
		Items.FormCommandSetMainItem.Title = NStr("en = 'Used to create new orders'; ru = 'Используется для создания новых заказов';pl = 'Służy do tworzenia nowych zamówień';es_ES = 'Solía crear nuevas órdenes';es_CO = 'Solía crear nuevas órdenes';tr = 'Yeni siparişler oluşturmak için kullanılır';it = 'Utilizzato per creare nuovi ordini';de = 'Wird verwendet, um neue Aufträge zu erstellen'");
		Items.FormCommandSetMainItem.Enabled = False;
	EndIf;
	
EndProcedure

#EndRegion