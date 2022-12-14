
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Parameters.Property("ProductionTask", ProductionTask);
	
	ProductionTaskQuantity = Common.ObjectAttributeValue(ProductionTask, "OperationQuantity");
	
	Items.SplittingTableQuantity.MaxValue = ProductionTaskQuantity;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	RecalculateSubtotal();
	
EndProcedure

#EndRegion

#Region SplittingTableFormTableItemsEventHandlers

&AtClient
Procedure SplittingTableAfterDeleteRow(Item)
	
	RecalculateSubtotal();
	
EndProcedure

&AtClient
Procedure SplittingTableBeforeAddRow(Item, Cancel, Clone, Parent, Folder, Parameter)
	
	RecalculateSubtotal();
	
EndProcedure

&AtClient
Procedure SplittingTableOnEditEnd(Item, NewRow, CancelEdit)
	
	RecalculateSubtotal();
	
EndProcedure

&AtClient
Procedure SplittingTableProductionTaskStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
EndProcedure

&AtClient
Procedure SplittingTableQuantityOnChange(Item)
	
	RecalculateSubtotal();
	
	If TotalQuantity < ProductionTaskQuantity Then
		
		NewLine = SplittingTable.Add();
		NewLine.Quantity = ProductionTaskQuantity - TotalQuantity;
		RecalculateSubtotal();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure SplittingTableSelection(Item, SelectedRow, Field, StandardProcessing)
	
	If Field.Name = "SplittingTableProductionTask" Then
		
		StandardProcessing = False;
		SelectedProductionTask = SplittingTable[SelectedRow].ProductionTask;
		
		If ValueIsFilled(SelectedProductionTask) Then
			ShowValue(, SelectedProductionTask);
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure SplitTask(Command)
	
	RecalculateSubtotal();
	
	If SplitTaskAtServer() Then
		
		Items.FormSplitTask.Enabled = False;
		Items.SplittingTableProductionTask.Visible = True;
		Items.SplittingTable.ReadOnly = True;
		
		Notify("ProductionTaskStatuseChanged", CommonClientServer.ValueInArray(ProductionTask));
		NotifyChanged(ProductionTask);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Function SplitTaskAtServer()
	
	Result = True;

	If TotalQuantity <> ProductionTaskQuantity Then
		
		Result = False;
		ErrorMessage = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'The total quantity must match quantity %2 specified in %1.'; ru = '?????????? ???????????????????? ???????????? ?????????????????????????????? ???????????????????? %2 , ???????????????????? ?? %1.';pl = 'Ilo???? og??lna powinna odpowiada?? ilo??ci %2 okre??lonej w %1.';es_ES = 'La cantidad total deber?? coincidir con la cantidad %2 especificada en %1.';es_CO = 'La cantidad total deber?? coincidir con la cantidad %2 especificada en %1.';tr = 'Toplam miktar ??urada belirtilen %2 miktar??yla e??le??melidir: %1.';it = 'La quantit?? totale deve corrispondere alla quantit?? %2 specificata in %1.';de = 'Die Gesamtmenge muss mit der in %1 angegebenen Menge %2 ??bereinstimmen.'"),
			ProductionTask,
			ProductionTaskQuantity);
			
		CommonClientServer.MessageToUser(ErrorMessage);
		
	ElsIf SplittingTable.Count() <=1 Then
		
		Result = False;
		ErrorMessage = NStr("en = 'The table must contain at least two lines.'; ru = '?????????????? ???????????? ??????????????????, ?????? ??????????????, ?????? ????????????.';pl = 'Tabela powinna zawiera?? co najmniej dwa wiersze.';es_ES = 'La tabla deber?? contener al menos dos l??neas.';es_CO = 'La tabla deber?? contener al menos dos l??neas.';tr = 'Tablo en az iki sat??r i??ermelidir.';it = 'La tabella deve contenere almeno due righe.';de = 'Die Tabelle muss mindestens zwei Zeilen enthalten.'");
		CommonClientServer.MessageToUser(ErrorMessage);
		
	Else
		
		BeginTransaction();
		Try
			
			For Each TaskLine In SplittingTable Do
				
				If TaskLine.Quantity > 0 Then
					
					TaskLine.ProductionTask = CreateProductionTask(TaskLine.Quantity);
					
				EndIf;
				
			EndDo;
			
			InformationRegisters.ProductionTaskStatuses.SetProductionTaskStatus(ProductionTask, Enums.ProductionTaskStatuses.Split);
			
			CommitTransaction();
			
		Except
			
			RollbackTransaction();
			Result = False;
			
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot save document ""%1""'; ru = '???? ?????????????? ???????????????? ???????????????? ""%1""';pl = 'Nie mo??na zapisa?? dokumentu ""%1""';es_ES = 'Ha ocurrido un error al guardar el documento ""%1""';es_CO = 'Ha ocurrido un error al guardar el documento ""%1""';tr = '""%1"" belgesi saklanam??yor';it = 'Impossibile salvare il documento ""%1""';de = 'Fehler beim Speichern des Dokuments ""%1""'"),
				BriefErrorDescription(ErrorInfo()));
			
			CommonClientServer.MessageToUser(ErrorDescription);
			
		EndTry;
		
	EndIf;
	
	Return Result;
	
EndFunction

&AtServer
Function CreateProductionTask(TaskQuantity)
	
	NewTask = ProductionTask.Copy();
	
	NewTask.Author = Users.CurrentUser();
	NewTask.Date = CurrentSessionDate();
	
	Factor = ?(NewTask.OperationQuantity = 0, 1, TaskQuantity / NewTask.OperationQuantity);
	NewTask.OperationQuantity = TaskQuantity;
	
	For Each InventoryLine In NewTask.Inventory Do
		InventoryLine.Quantity = InventoryLine.Quantity * Factor;
	EndDo;
	
	NewTask.ParentTask = ProductionTask;
	
	NewTask.Write(DocumentWriteMode.Posting);
	
	Return NewTask.Ref;
	
EndFunction

&AtClient
Procedure RecalculateSubtotal()
	
	TotalQuantity = SplittingTable.Total("Quantity");
	
EndProcedure

#EndRegion