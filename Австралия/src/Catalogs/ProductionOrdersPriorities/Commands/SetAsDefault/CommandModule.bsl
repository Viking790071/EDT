#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	If SetPriorityAsDefault(CommandParameter) Then
		Notify("PrioritySetAsDefault", CommandParameter);
	Else
		CommonClientServer.MessageToUser(NStr("en = 'This status is not active and cannot be set as default.'; ru = 'Этот статус не активен и не может быть установлен как статус по умолчанию.';pl = 'Ten status nie jest aktywny i nie może być ustawiony jako domyślny.';es_ES = 'Este estado no está activo y no se puede establecer como predeterminado.';es_CO = 'Este estado no está activo y no se puede establecer como predeterminado.';tr = 'Bu durum aktif değil ve varsayılan olarak ayarlanamaz.';it = 'Questo stato non è attivo e non può essere impostato come impostazione predefinita.';de = 'Dieser Status ist nicht aktiv und kann nicht als Standard eingestellt werden.'"));
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Function SetPriorityAsDefault(PriorityRef)
	
	Result = False;
	
	If Common.ObjectAttributeValue(PriorityRef, "Active") Then
		
		Constants.DefaultProductionOrdersPriority.Set(PriorityRef);
		Result = True;
		
	EndIf;
	
	Return Result;
	
EndFunction

#EndRegion

