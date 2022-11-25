#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	GetDefaultProductionOrdersPriority();
	SetConditionalAppearance();
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject);
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "PrioritySetAsDefault" Then
		
		GetDefaultProductionOrdersPriority();
		SetConditionalAppearance();
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()
	
	DefPriorityCA = NStr("en = 'Default priority'; ru = 'Приоритет по умолчанию';pl = 'Priorytet domyślny';es_ES = 'Prioridad por defecto';es_CO = 'Prioridad por defecto';tr = 'Varsayılan öncelik';it = 'Priorità predefinita';de = 'Standard-Prioritätseinstellungen'");
	
	// Clear conditional appearance
	ListToDel = New Array;
	For Each CAItem In List.ConditionalAppearance.Items Do
		
		If CAItem.Presentation = DefPriorityCA Then
			
			ListToDel.Add(CAItem);
			
		EndIf;
		
	EndDo;
	
	For Each ItemToDel In ListToDel Do
		List.ConditionalAppearance.Items.Delete(ItemToDel);
	EndDo;
	
	NewConditionalAppearance = List.ConditionalAppearance.Items.Add();
	NewConditionalAppearance.Presentation = NStr("en = 'Default priority'; ru = 'Приоритет по умолчанию';pl = 'Priorytet domyślny';es_ES = 'Prioridad por defecto';es_CO = 'Prioridad por defecto';tr = 'Varsayılan öncelik';it = 'Priorità predefinita';de = 'Standard-Prioritätseinstellungen'");
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"Ref",
		DefaultProductionOrdersPriority);
	
	WorkWithForm.AddAppearanceField(NewConditionalAppearance, "Description, Code");
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "Font", New Font(,, True));
	
EndProcedure

&AtServer
Procedure GetDefaultProductionOrdersPriority()
	
	DefaultProductionOrdersPriority = Constants.DefaultProductionOrdersPriority.Get();
	
EndProcedure

#EndRegion
