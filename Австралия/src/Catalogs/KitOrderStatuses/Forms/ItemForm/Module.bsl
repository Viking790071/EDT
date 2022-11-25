#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If ValueIsFilled(Object.Ref) Then
		Color = Object.Ref.Color.Get();
		If Object.Ref = DriveReUse.GetValueOfSetting("StatusOfNewKitOrder") Then
			Items.FormCommandSetMainItem.Title = NStr("en = 'Initial status for new Kit orders'; ru = 'Начальный статус новых заказов на комплектацию';pl = 'Status początkowy dla nowych Zamówień zestawów';es_ES = 'Estado inicial de nuevos pedidos del kit';es_CO = 'Estado inicial de nuevos pedidos del kit';tr = 'Yeni Set siparişleri için başlangıç durumu';it = 'Stato iniziale per nuovi Ordini kit';de = 'Grundstatus für neue Kit-Aufträge'");
			Items.FormCommandSetMainItem.Enabled = False;
		EndIf; 
	Else
		CopyingValue = Undefined;
		Parameters.Property("CopyingValue", CopyingValue);
		If CopyingValue <> Undefined Then
			Color = CopyingValue.Color.Get();
		Else
			Color = WebColors.Black;
		EndIf;
	EndIf;
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject, Object);
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If Color = WebColors.Black Then
		CurrentObject.Color = New ValueStorage(Undefined);
	Else
		CurrentObject.Color = New ValueStorage(Color);
	EndIf;

	NativeLanguagesSupportServer.BeforeWriteAtServer(CurrentObject);
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	Notify("Record_KitOrderStates");
	
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

#Region FormCommandsEventHandlers

// Procedure - Command execution handler SetMainItem.
//
&AtClient
Procedure CommandSetMainItem(Command)
	
	If ValueIsFilled(Object.Ref) Then
		SetMainItem();
		Notify("UserSettingsChanged");
	Else
		ShowMessageBox(Undefined,NStr("en = 'The status details are not saved yet. To be able to continue, save them.'; ru = 'Описание статуса еще не записано. Запишите его для продолжения.';pl = 'Szczegóły statusu jeszcze nie są zapisane. Aby mieć możliwość kontynuowania, zapisz je.';es_ES = 'Los detalles del estado todavía no se han guardado. Para poder continuar, guárdelos.';es_CO = 'Los detalles del estado todavía no se han guardado. Para poder continuar, guárdelos.';tr = 'Durum bilgileri kaydedilmedi. Devam edebilmek için bilgileri kaydedin.';it = 'I dettagli di stato non sono stati ancora salvati. Salvare per continuare.';de = 'Die Status-Einzelheiten sind noch nicht gespeichert. Speichern Sie diese zum Fortfahren.'"));
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

// Procedure saves the selected item in settings.
//
&AtServer
Procedure SetMainItem()
	
	If Object.Ref <> DriveReUse.GetValueOfSetting("StatusOfNewKitOrder") Then
		DriveServer.SetUserSetting(Object.Ref, "StatusOfNewKitOrder");
		Items.FormCommandSetMainItem.Title = NStr("en = 'Initial status for new Kit orders'; ru = 'Начальный статус новых заказов на комплектацию';pl = 'Status początkowy dla nowych Zamówień zestawów';es_ES = 'Estado inicial de nuevos pedidos del kit';es_CO = 'Estado inicial de nuevos pedidos del kit';tr = 'Yeni Set siparişleri için başlangıç durumu';it = 'Stato iniziale per nuovi Ordini kit';de = 'Grundstatus für neue Kit-Aufträge'");
		Items.FormCommandSetMainItem.Enabled = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_Open(Item, StandardProcessing)
	NativeLanguagesSupportClient.OnOpen(ThisObject, Object, Item, StandardProcessing);
EndProcedure

#EndRegion