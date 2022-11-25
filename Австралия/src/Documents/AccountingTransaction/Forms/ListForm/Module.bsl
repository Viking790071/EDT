#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Parameters.Property("IsManual", IsManual);
	
	If TypeOf(Parameters.CurrentRow) = Type("DocumentRef.AccountingTransaction") Then
		IsManual = Common.ObjectAttributeValue(Parameters.CurrentRow, "IsManual");
	EndIf;
	
	DriveClientServer.SetListFilterItem(List, "IsManual", IsManual, True);
	
	SetForm();
	SetTitle();
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.AttachableCommands
	AttachableCommands.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClient.StartCommandUpdate(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "RefreshAccountingTransaction" Then
		Items.List.Refresh();
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure FilterCompanyOnChange(Item)
	
	DriveClientServer.SetListFilterItem(List, 
		"Company", 
		FilterCompany, 
		ValueIsFilled(FilterCompany));	
	
EndProcedure

&AtClient
Procedure FilterTypeOfAccountingOnChange(Item)
	
	DriveClientServer.SetListFilterItem(List, 
		"TypeOfAccounting", 
		FilterTypeOfAccounting, 
		ValueIsFilled(FilterTypeOfAccounting));
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersList

&AtClient
Procedure ListOnActivateRow(Item)
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClient.StartCommandUpdate(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetForm()
	
	ButtonNameCopy = NStr("en = 'Copy'; ru = 'Скопировать';pl = 'Kopiuj';es_ES = 'Copia';es_CO = 'Copia';tr = 'Kopyala';it = 'Copia';de = 'Kopieren'");
	ButtonNameCreate = NStr("en = 'Create'; ru = 'Создать';pl = 'Utwórz';es_ES = 'Crear';es_CO = 'Crear';tr = 'Oluştur';it = 'Crea';de = 'Erstellen'");
	
	If Not IsManual Then
		For Each CommandItem In Items.GroupCommandBar.ChildItems Do
			If StrFind(CommandItem.Name, ButtonNameCopy) > 0
				Or StrFind(CommandItem.Name, ButtonNameCreate) > 0 Then
			
			CommandItem.Visible = False;
			
			EndIf;
		EndDo;
		For Each CommandItem In Items.List.ContextMenu.ChildItems Do
			If StrFind(CommandItem.Name, ButtonNameCopy) > 0
				Or StrFind(CommandItem.Name, ButtonNameCreate) > 0 Then
			
			CommandItem.Visible = False;
			
			EndIf;
		EndDo;
	EndIf;
	
	Items.BasisDocument.Visible = Not IsManual;
	
EndProcedure

&AtServer
Procedure SetTitle()
	
	Title = ?(IsManual, GetTitleManual(), GetTitleDefault());
	
EndProcedure

&AtClientAtServerNoContext
Function GetTitleDefault()
	
	Return NStr("en = 'Accounting transactions'; ru = 'Бухгалтерские операции';pl = 'Transakcje księgowe';es_ES = 'Transacciones contables';es_CO = 'Transacciones contables';tr = 'Muhasebe işlemleri';it = 'Transazioni contabili';de = 'Buchhaltungstransaktionen'");
	
EndFunction

&AtClientAtServerNoContext
Function GetTitleManual()
	
	Return NStr("en = 'Manual accounting transactions'; ru = 'Ручные бухгалтерские операции';pl = 'Ręczne transakcje księgowe';es_ES = 'Transacciones contables manuales';es_CO = 'Transacciones contables manuales';tr = 'Manuel muhasebe işlemleri';it = 'Transazioni contabili manuali';de = 'Manuelle Buchhaltungstransaktionen'");
	
EndFunction

#Region LibrariesHandlers

// StandardSubsystems.AttachableCommands
&AtClient
Procedure Attachable_ExecuteCommand(Command)
	AttachableCommandsClient.ExecuteCommand(ThisObject, Command, Items.List);
EndProcedure

&AtServer
Procedure Attachable_ExecuteCommandAtServer(Context, Result)
	AttachableCommands.ExecuteCommand(ThisObject, Context, Items.List, Result);
EndProcedure

&AtClient
Procedure Attachable_UpdateCommands()
	AttachableCommandsClientServer.UpdateCommands(ThisObject, Items.List);
EndProcedure

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Clone, Parent, Folder, Parameter)
	If Not IsManual Then
		Cancel = True;
	EndIf;
EndProcedure
// End StandardSubsystems.AttachableCommands

#EndRegion

#EndRegion