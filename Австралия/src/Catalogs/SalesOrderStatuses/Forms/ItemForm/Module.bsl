////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS OF SAVING SETTINGS

// Procedure saves the selected item in settings.
//
&AtServer
Procedure SetMainItem()
	
	If Object.Ref <> DriveReUse.GetValueOfSetting("StatusOfNewSalesOrder") Then
		DriveServer.SetUserSetting(Object.Ref, "StatusOfNewSalesOrder");	
		Items.FormCommandSetMainItem.Title = "Used to create new orders";
		Items.FormCommandSetMainItem.Enabled = False;
	EndIf; 
		
EndProcedure

#Region ProcedureFormEventHandlers

// Procedure OnCreateAtServer
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If ValueIsFilled(Object.Ref) Then
		Color = Object.Ref.Color.Get();
		If Object.Ref = DriveReUse.GetValueOfSetting("StatusOfNewSalesOrder") Then
			Items.FormCommandSetMainItem.Title = "Used to create new orders";
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

// Procedure BeforeWriteAtServer
//
&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If Color = StyleColors.ToolTipTextColor Then
		CurrentObject.Color = New ValueStorage(Undefined);
	Else
		CurrentObject.Color = New ValueStorage(Color);
	EndIf;

	NativeLanguagesSupportServer.BeforeWriteAtServer(CurrentObject);
	
EndProcedure

// Procedure - Command execution handler SetMainItem.
//
&AtClient
Procedure CommandSetMainItem(Command)
	
	If ValueIsFilled(Object.Ref) Then
		SetMainItem();
		Notify("UserSettingsChanged");
	Else
		ShowMessageBox(Undefined,NStr("en = 'Save the changes first.'; ru = 'Сначала сохраните изменения.';pl = 'Najpierw zapisz zmiany.';es_ES = 'Guarde primero los cambios.';es_CO = 'Guarde primero los cambios.';tr = 'Önce değişiklikleri kaydedin.';it = 'Salvare prima le modifiche.';de = 'Speichern Sie zuerst die Änderungen.'"));
	EndIf;
	
EndProcedure

// Procedure BeforeWrite
//
&AtClient
Procedure AfterWrite(WriteParameters)
	
	Notify("Record_SalesOrderStates");
	
EndProcedure
// 

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)

	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)

	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure Attachable_Open(Item, StandardProcessing)
	NativeLanguagesSupportClient.OnOpen(ThisObject, Object, Item, StandardProcessing);
EndProcedure

#EndRegion
