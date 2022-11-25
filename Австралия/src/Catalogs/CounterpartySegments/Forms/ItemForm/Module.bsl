
#Region Variables

&AtClient
Var IdleHandlerParameters;

#EndRegion

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Key.IsEmpty() Then
		
		FillInAvailableRules();
		
		If ValueIsFilled(Parameters.CopyingValue) Then
			
			For Each Rule In Parameters.CopyingValue.UsedRules Do
				AvailableRule = FindTreeRow(AvailableRules.GetItems(), Rule.Name, Rule.DynamicRuleKey);
				If AvailableRule <> Undefined Then
					RuleSettings = Rule.Settings.Get();
					NewRule = UsedRules.Add();
					FillPropertyValues(NewRule, AvailableRule);
					NewRule.ComparisonType = RuleSettings.ComparisonType;
					NewRule.Value = RuleSettings.Value;
				EndIf;
			EndDo;
			
		EndIf;
		
	EndIf;
	
	FillInCounterpartyKindValues();
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject, Object);
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	FillInAvailableRules();
	
	UsedRules.Clear();
	
	For Each Rule In CurrentObject.UsedRules Do
		AvailableRule = FindTreeRow(AvailableRules.GetItems(), Rule.Name, Rule.DynamicRuleKey);
		If AvailableRule <> Undefined Then
			RuleSettings = Rule.Settings.Get();
			NewRule = UsedRules.Add();
			FillPropertyValues(NewRule, AvailableRule);
			NewRule.ComparisonType = RuleSettings.ComparisonType;
			NewRule.Value = RuleSettings.Value;
		EndIf;
	EndDo;

	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	CurrentObject.UsedRules.Clear();
	
	For Each Rule In UsedRules Do
		NewRule = CurrentObject.UsedRules.Add();
		NewRule.Name = Rule.Name;
		NewRule.DynamicRuleKey = Rule.DynamicRuleKey;
		NewRule.Settings = New ValueStorage(
			New Structure("ComparisonType, Value", Rule.ComparisonType, Rule.Value));
	EndDo;

	NativeLanguagesSupportServer.BeforeWriteAtServer(CurrentObject);
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	Notify("AfterSegmentWriting", Object.Ref);
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)

	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure UpdateSegmentContent(Command)
	
	If Object.Ref.IsEmpty() Or Modified Then
		Notification = New NotifyDescription(
			"UpdateSegmentContentEnd",
			ThisObject);
		QueryText = NStr(
			"en = 'Click OK for the changes to take effect or Cancel to return.'; ru = 'Нажмите OK для применения изменений или Отмена для возврата.';pl = 'Kliknij OK, aby zmiany zaczęły obowiązywać lub Anuluj, aby powrócić.';es_ES = 'Haga clic en Aceptar para que los cambios surtan efecto o en Cancelar para volver.';es_CO = 'Haga clic en Aceptar para que los cambios surtan efecto o en Cancelar para volver.';tr = 'Değişikliklerin uygulanması için Tamam''a, geri dönmek için İptal''e tıklayın.';it = 'Premere OK per confermare le modifiche o Cancella per ritornare.';de = 'Klicken Sie auf OK, damit die Änderungen wirksam werden, oder auf Abbrechen, um zurückzukehren.'");
		ShowQueryBox(Notification, QueryText, QuestionDialogMode.OKCancel);
		Return;
	EndIf;
		
	ClearMessages();
	ExecutionResult = GenerateCounterpartySegmentsAtServer();
	If Not ExecutionResult.Status = "Completed" Then
		TimeConsumingOperationsClient.InitIdleHandlerParameters(IdleHandlerParameters);
		AttachIdleHandler("Attachable_CheckJobExecution", 0.1, True);
	EndIf;

EndProcedure

&AtClient
Procedure UpdateSegmentContentEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.OK Then
		
		Write();
		
		If Object.Ref.IsEmpty() Then
			Return;
		EndIf;
		
		ClearMessages();
		ExecutionResult = GenerateCounterpartySegmentsAtServer();
		If Not ExecutionResult.Status = "Completed" Then
			TimeConsumingOperationsClient.InitIdleHandlerParameters(IdleHandlerParameters);
			AttachIdleHandler("Attachable_CheckJobExecution", 0.1, True);
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormAttributesEventsHandlers

&AtClient
Procedure AvailableRulesSelection(Item, SelectedRow, Field, StandardProcessing)
	
	AvailableRule = AvailableRules.FindByID(SelectedRow);
	If AvailableRule.IsFolder Then
		Return;
	EndIf;
	
	StandardProcessing = False;
	FoundRules = UsedRules.FindRows(New Structure("Name, DynamicRuleKey", AvailableRule.Name, AvailableRule.DynamicRuleKey));
	If AvailableRule.MultipleUse Or FoundRules.Count() = 0 Then
		NewRule = UsedRules.Add();
		FillPropertyValues(NewRule, AvailableRule);
		Items.UsedRules.CurrentRow = NewRule.GetID();
		Modified = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure UsedRulesSelection(Item, SelectedRow, Field, StandardProcessing)
	
	If Field.Name = "UsedRulesPresentation" Then
		Rule = UsedRules.FindByID(SelectedRow);
		UsedRules.Delete(Rule);
		Modified = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure UsedRulesOnActivateRow(Item)
	
	If Items.UsedRules.CurrentRow = Undefined Then
		Return;
	EndIf;
	
	UsedRule = UsedRules.FindByID(Items.UsedRules.CurrentRow);
	AvailableRule = FindTreeRow(AvailableRules.GetItems(), UsedRule.Name, UsedRule.DynamicRuleKey);
	If AvailableRule = Undefined Then
		Return;
	EndIf;
	
	DriveClientServer.FillListByList(AvailableRule.AvailableComparisonTypes, Items.UsedRulesComparisonType.ChoiceList);
	Items.UsedRulesComparisonType.ReadOnly = AvailableRule.AvailableComparisonTypes.Count() <= 1;
	
	FillPropertyValues(Items.UsedRulesValue, AvailableRule.ValueProperties);
	If ComparisonTypeList(UsedRule.ComparisonType) Then
		Items.UsedRulesValue.TypeRestriction = New TypeDescription("ValueList");
		If TypeOf(UsedRule.Value) <> Type("ValueList") Then
			UsedRule.Value = New ValueList;
			UsedRule.Value.ValueType = AvailableRule.ValueProperties.TypeRestriction;
		EndIf;
	Else
		UsedRule.Value = AvailableRule.ValueProperties.TypeRestriction.AdjustValue(UsedRule.Value);
	EndIf;
	Items.UsedRulesValue.ReadOnly = UsedRule.ComparisonType = DataCompositionComparisonType.Filled Or UsedRule.ComparisonType = DataCompositionComparisonType.NotFilled;
	
	If UsedRule.Name = "CounterpartyKind" Then
		Items.UsedRulesValue.ChoiceButton = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure UsedRulesDragAndDropCheck(Item, DragParameters, StandardProcessing, String, Field)
	
	If DragParameters.Value.Count() > 0 AND TypeOf(DragParameters.Value[0]) = Type("FormDataTreeItem") Then
		StandardProcessing = False;
		For Each AvailableRule In DragParameters.Value Do
			If AvailableRule.IsFolder Then
				DragParameters.Action = DragAction.Cancel;
				Return;
			EndIf;
		EndDo;
		DragParameters.Action = DragAction.Choice;
	EndIf;
	
EndProcedure

&AtClient
Procedure UsedRulesDragAndDrop(Item, DragParameters, StandardProcessing, String, Field)
	
	StandardProcessing = False;
	If DragParameters.Value.Count() = 0 Or TypeOf(DragParameters.Value[0]) <> Type("FormDataTreeItem") Then
		Return;
	EndIf;
	
	Filter = New Structure("Name, DynamicRuleKey");
	For Each AvailableRule In DragParameters.Value Do
		If AvailableRule.IsFolder Then
			Continue;
		EndIf;
		Filter.Name = AvailableRule.Name;
		Filter.DynamicRuleKey = AvailableRule.DynamicRuleKey;
		FoundRules = UsedRules.FindRows(Filter);
		If AvailableRule.MultipleUse Or FoundRules.Count() = 0 Then
			NewRule = UsedRules.Add();
			FillPropertyValues(NewRule, AvailableRule);
		EndIf;
	EndDo;
	
	If NewRule <> Undefined Then
		Items.UsedRules.CurrentRow = NewRule.GetID();
		Modified = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure UsedRulesComparisonTypeOnChange(Item)
	
	If Items.UsedRules.CurrentRow = Undefined Then
		Return;
	EndIf;
	
	UsedRule = UsedRules.FindByID(Items.UsedRules.CurrentRow);
	AvailableRule = FindTreeRow(AvailableRules.GetItems(), UsedRule.Name, UsedRule.DynamicRuleKey);
	If AvailableRule = Undefined Then
		Return;
	EndIf;

	Value = UsedRule.Value;
	
	If ComparisonTypeList(UsedRule.ComparisonType) Then
		TypeDescriptionList = New TypeDescription("ValueList");
		UsedRule.Value = TypeDescriptionList.AdjustValue(Value);
		UsedRule.Value.ValueType = AvailableRule.ValueProperties.TypeRestriction;
		Items.UsedRulesValue.TypeRestriction = New TypeDescription("ValueList");
		Items.UsedRulesValue.ReadOnly = False;
		
		If UsedRule.Name = "CounterpartyKind" Then
			UsedRule.Value.AvailableValues = CounterpartyKindValues;
		EndIf;

	ElsIf UsedRule.ComparisonType = DataCompositionComparisonType.Filled Or UsedRule.ComparisonType = DataCompositionComparisonType.NotFilled Then
		UsedRule.Value = AvailableRule.ValueProperties.TypeRestriction.AdjustValue(Value);
		Items.UsedRulesValue.ReadOnly = True;
	Else
		UsedRule.Value = AvailableRule.ValueProperties.TypeRestriction.AdjustValue(Value);
		Items.UsedRulesValue.TypeRestriction = AvailableRule.ValueProperties.TypeRestriction;
		Items.UsedRulesValue.ReadOnly = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure UsedRulesValueStartChoice(Item, ChoiceData, StandardProcessing)
	
	CurrentData = Items.UsedRules.CurrentData;
	
	If CurrentData.Name = "CounterpartyKind" Then 
		If Item.TypeRestriction.ContainsType(Type("String")) Then
			StandardProcessing = False;
			ChoiceData = CounterpartyKindValues;
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure UsedRulesValueChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	If Items.UsedRules.CurrentData.Name = "CounterpartyKind" Then
		UsedRule = UsedRules.FindByID(Items.UsedRules.CurrentRow);
		UsedRule.DynamicRuleKey = SelectedValue;
		SelectedValue = CounterpartyKindValues.FindByValue(SelectedValue).Presentation;
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_Open(Item, StandardProcessing)
	NativeLanguagesSupportClient.OnOpen(ThisObject, Object, Item, StandardProcessing);
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure FillInAvailableRules()
	
	TreeItems = AvailableRules.GetItems();
	TreeItems.Clear();
	
	Rules = Catalogs.CounterpartySegments.GetAvailableFilterRules();
	Common.FillFormDataTreeItemCollection(TreeItems, Rules);
	
	FillInPictureIndex(TreeItems);
	
	ChoiceParameterLinks = New Array;
	ChoiceParameterLinks.Add(New ChoiceParameterLink("Filter.Owner", "Items.UsedRules.CurrentData.DynamicRuleKey"));
	Items.UsedRulesValue.ChoiceParameterLinks = New FixedArray(ChoiceParameterLinks);
	
EndProcedure

&AtServerNoContext
Procedure FillInPictureIndex(TreeItems)
	
	For Each TreeItem In TreeItems Do
		TreeItem.PictureIndex = ?(TreeItem.IsFolder, 2, 5);
		ChildItems = TreeItem.GetItems();
		If ChildItems.Count() > 0 Then
			FillInPictureIndex(ChildItems);
		EndIf;
	EndDo;
	
EndProcedure

&AtClientAtServerNoContext
Function ComparisonTypeList(ComparisonTypeRules)
	
	If ComparisonTypeRules = DataCompositionComparisonType.InList
		Or ComparisonTypeRules = DataCompositionComparisonType.NotInList
		Or ComparisonTypeRules = DataCompositionComparisonType.InListByHierarchy
		Or ComparisonTypeRules = DataCompositionComparisonType.NotInListByHierarchy Then
		Return True;
	Else
		Return False;
	EndIf;
	
EndFunction

&AtClientAtServerNoContext
Function FindTreeRow(TreeItemCollection, Name, DynamicRuleKey)
	
	If TypeOf(DynamicRuleKey) = Type("String") Then
		DynamicRuleKey = Undefined;	
	EndIf;
	
	For Each TreeItem In TreeItemCollection Do
		If TreeItem.Name = Name AND TreeItem.DynamicRuleKey = DynamicRuleKey Then
			Return TreeItem;
		EndIf;
		RowItems = TreeItem.GetItems();
		If RowItems.Count() > 0 Then
			FoundString = FindTreeRow(RowItems, Name, DynamicRuleKey);
			If FoundString <> Undefined Then
				Return FoundString;
			EndIf;
		EndIf;
	EndDo;
	
	Return Undefined;
	
EndFunction

&AtServer
Procedure FillInCounterpartyKindValues()
	
	CounterpartyKindValues.Add("Customer", NStr("en = 'Customer'; ru = 'Покупатель';pl = 'Nabywca';es_ES = 'Cliente';es_CO = 'Cliente';tr = 'Müşteri';it = 'Cliente';de = 'Kunde'"));
	CounterpartyKindValues.Add("Supplier", NStr("en = 'Supplier'; ru = 'Поставщик';pl = 'Dostawca';es_ES = 'Proveedor';es_CO = 'Proveedor';tr = 'Tedarikçi';it = 'Fornitore';de = 'Lieferant'"));
	CounterpartyKindValues.Add("OtherRelationship", NStr("en = 'Other relationship'; ru = 'Прочие отношения';pl = 'Inna relacja';es_ES = 'Otras relaciones';es_CO = 'Otras relaciones';tr = 'Diğer ilişkiler';it = 'Altre relazioni';de = 'Andere Beziehung'"));
	
EndProcedure

#Region LibrariesHandlers

// StandardSubsystems.ObjectAttributesLock

&AtClient
Procedure Attachable_AllowObjectAttributesEditing(Command)
	ObjectAttributesLockClient.AllowObjectAttributeEdit(ThisObject);
EndProcedure

// End StandardSubsystems.ObjectAttributesLock

#EndRegion

#Region BackgroundJobs

&AtServer
Function GenerateCounterpartySegmentsAtServer()
	
	JobID = Undefined;
	
	ProcedureName = "ContactsClassification.ExecuteCounterpartySegmentsGeneration";
	
	StartSettings = TimeConsumingOperations.BackgroundExecutionParameters(UUID);
	StartSettings.BackgroundJobDescription = NStr("en = 'Counterparty segments generation'; ru = 'Создание сегментов контрагентов';pl = 'Generacja segmentów kontrahenta';es_ES = 'Generación de segmentos de contrapartida';es_CO = 'Generación de segmentos de contrapartida';tr = 'Cari hesap segment oluşturma';it = 'Generazione segmenti controparti';de = 'Generierung von Geschäftspartnersegmenten'");
	
	ExecutionResult = TimeConsumingOperations.ExecuteInBackground(
		ProcedureName,
		New Structure("Segment", Object.Ref),
		StartSettings);
	
	StorageAddress = ExecutionResult.ResultAddress;
	JobID = ExecutionResult.JobID;
	
	If ExecutionResult.Status = "Completed" Then
		MessageText = NStr("en = 'Counterparty segments have been updated successfully.'; ru = 'Сегменты контрагентов успешно обновлены.';pl = 'Segmenty kontrahenta zostali zaktualizowani pomyślnie.';es_ES = 'Se han actualizado con éxito los segmentos de contrapartida.';es_CO = 'Se han actualizado con éxito los segmentos de contrapartida.';tr = 'Cari hesap segmentleri başarıyla güncellendi.';it = 'I segmenti delle controparti sono stati aggiornati con successo.';de = 'Die Geschäftspartner-Segmente wurden erfolgreich aktualisiert.'");
		CommonClientServer.MessageToUser(MessageText);
	EndIf;
	
	Return ExecutionResult;

EndFunction

&AtClient
Procedure Attachable_CheckJobExecution()
	
	Try
		If JobCompleted(JobID) Then
			MessageText = NStr("en = 'Counterparty segment have been updated successfully.'; ru = 'Сегмент контрагентов успешно обновлен.';pl = 'Segment kontrahenta został zaktualizowany pomyślnie';es_ES = 'Se ha actualizado con éxito el segmento de contrapartida.';es_CO = 'Se ha actualizado con éxito el segmento de contrapartida.';tr = 'Cari hesap segmentleri başarıyla güncellendi.';it = 'Il segmento controparte è stato aggiornato con successo.';de = 'Das Geschäftspartner-Segment wurde erfolgreich aktualisiert.'");
			CommonClientServer.MessageToUser(MessageText);
		Else
			TimeConsumingOperationsClient.UpdateIdleHandlerParameters(IdleHandlerParameters);
			AttachIdleHandler(
				"Attachable_CheckJobExecution",
				IdleHandlerParameters.CurrentInterval,
				True);
		EndIf;
	Except
		Raise DetailErrorDescription(ErrorInfo());
	EndTry;
	
EndProcedure

&AtServerNoContext
Function JobCompleted(JobID)
	
	Return TimeConsumingOperations.JobCompleted(JobID);
	
EndFunction

#EndRegion

#EndRegion
