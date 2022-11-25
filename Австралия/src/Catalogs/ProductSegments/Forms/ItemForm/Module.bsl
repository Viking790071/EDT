
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

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)

	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	Notify("AfterSegmentWriting", Object.Ref);
	
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
			"en = 'Click OK for the changes to take effect or Cancel to return.'; ru = 'Нажмите OK для применения изменений или Отмена для возврата.';pl = 'Kliknij OK, aby zmiany zaczęły obowiązywać lub Anuluj, aby powrócić.';es_ES = 'Haga clic en Aceptar para que los cambios surtan efecto o en Cancelar para volver.';es_CO = 'Haga clic en Aceptar para que los cambios surtan efecto o en Cancelar para volver.';tr = 'Değişikliklerin uygulanması için Tamam''a, geri dönmek için İptal''e tıklayın.';it = 'Premere OK per confermare le modifiche o Cancella per tornare indietro.';de = 'Klicken Sie auf OK, damit die Änderungen wirksam werden, oder auf Abbrechen, um zurückzukehren.'");
		ShowQueryBox(Notification, QueryText, QuestionDialogMode.OKCancel);
		Return;
	EndIf;
		
	ClearMessages();
	ExecutionResult = GenerateProductSegmentsAtServer();
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
		
		SegmentsServerCall.GenerateProductSegments(Object.Ref);
		
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
	Items.UsedRulesValue.ChoiceFoldersAndItems = FoldersAndItems.Items;
	
	If ComparisonTypeList(UsedRule.ComparisonType) Then
		TypeDescriptionList = New TypeDescription("ValueList");
		UsedRule.Value = TypeDescriptionList.AdjustValue(Value);
		UsedRule.Value.ValueType = AvailableRule.ValueProperties.TypeRestriction;
		Items.UsedRulesValue.TypeRestriction = New TypeDescription("ValueList");
		Items.UsedRulesValue.ReadOnly = False;
	ElsIf UsedRule.ComparisonType = DataCompositionComparisonType.Filled Or UsedRule.ComparisonType = DataCompositionComparisonType.NotFilled Then
		UsedRule.Value = AvailableRule.ValueProperties.TypeRestriction.AdjustValue(Value);
		Items.UsedRulesValue.ReadOnly = True;
	ElsIf UsedRule.ComparisonType = DataCompositionComparisonType.InHierarchy Or UsedRule.ComparisonType = DataCompositionComparisonType.NotInHierarchy Then
		UsedRule.Value = AvailableRule.ValueProperties.TypeRestriction.AdjustValue(Value);
		Items.UsedRulesValue.TypeRestriction = AvailableRule.ValueProperties.TypeRestriction;
		Items.UsedRulesValue.ReadOnly = False;
		Items.UsedRulesValue.ChoiceFoldersAndItems = FoldersAndItems.Folders;
	Else
		UsedRule.Value = AvailableRule.ValueProperties.TypeRestriction.AdjustValue(Value);
		Items.UsedRulesValue.TypeRestriction = AvailableRule.ValueProperties.TypeRestriction;
		Items.UsedRulesValue.ReadOnly = False;
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
	
	Rules = Catalogs.ProductSegments.GetAvailableFilterRules();
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
Function GenerateProductSegmentsAtServer()
	
	JobID = Undefined;
	
	ProcedureName = "SegmentsServer.ExecuteProductSegmentsGeneration";
	StartSettings = TimeConsumingOperations.BackgroundExecutionParameters(UUID);
	StartSettings.BackgroundJobDescription = NStr("en = 'Product segments generation'; ru = 'Генерирование сегментов номенклатуры';pl = 'Generacja segmentów produktu';es_ES = 'Generación de segmentos de productos';es_CO = 'Generación de segmentos de productos';tr = 'Ürün segmenti oluşturma';it = 'Generazione segmenti articolo';de = 'Generierung von Produktsegmenten'");
	
	ExecutionResult = TimeConsumingOperations.ExecuteInBackground(
		ProcedureName,
		New Structure("Segment", Object.Ref),
		StartSettings);
	
	StorageAddress = ExecutionResult.ResultAddress;
	JobID = ExecutionResult.JobID;
	
	If ExecutionResult.Status = "Completed" Then
		MessageText = NStr("en = 'Product segments have been updated successfully.'; ru = 'Сегменты номенклатуры успешно обновлены.';pl = 'Segmenty produktu zostali zaktualizowani pomyślnie.';es_ES = 'Se han actualizado con éxito los segmentos del producto.';es_CO = 'Se han actualizado con éxito los segmentos del producto.';tr = 'Ürün segmentleri başarıyla güncellendi.';it = 'I segmenti articolo sono stati aggiornati con successo.';de = 'Die Produktsegmente wurden erfolgreich aktualisiert.'");
		CommonClientServer.MessageToUser(MessageText);
	EndIf;
	
	Return ExecutionResult;

EndFunction

&AtClient
Procedure Attachable_CheckJobExecution()
	
	Try
		If JobCompleted(JobID) Then
			MessageText = NStr("en = 'Product segment have been updated successfully.'; ru = 'Сегмент номенклатуры успешно обновлен.';pl = 'Segment produktu został zaktualizowany pomyślnie.';es_ES = 'Se ha actualizado con éxito el segmento del producto.';es_CO = 'Se ha actualizado con éxito el segmento del producto.';tr = 'Ürün segmenti başarıyla güncellendi.';it = 'Il segmento prodotto è stato aggiornato con successo.';de = 'Das Produktsegment wurde erfolgreich aktualisiert.'");
			CommonClientServer.MessageToUser(MessageText);
		Else
			TimeConsumingOperationsClient.InitIdleHandlerParameters(IdleHandlerParameters);
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
