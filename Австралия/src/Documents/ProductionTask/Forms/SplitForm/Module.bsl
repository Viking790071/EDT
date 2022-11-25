
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
			NStr("en = 'The total quantity must match quantity %2 specified in %1.'; ru = 'Общее количество должно соответствовать количеству %2 , указанному в %1.';pl = 'Ilość ogólna powinna odpowiadać ilości %2 określonej w %1.';es_ES = 'La cantidad total deberá coincidir con la cantidad %2 especificada en %1.';es_CO = 'La cantidad total deberá coincidir con la cantidad %2 especificada en %1.';tr = 'Toplam miktar şurada belirtilen %2 miktarıyla eşleşmelidir: %1.';it = 'La quantità totale deve corrispondere alla quantità %2 specificata in %1.';de = 'Die Gesamtmenge muss mit der in %1 angegebenen Menge %2 übereinstimmen.'"),
			ProductionTask,
			ProductionTaskQuantity);
			
		CommonClientServer.MessageToUser(ErrorMessage);
		
	ElsIf SplittingTable.Count() <=1 Then
		
		Result = False;
		ErrorMessage = NStr("en = 'The table must contain at least two lines.'; ru = 'Таблица должна содержать, как минимум, две строки.';pl = 'Tabela powinna zawierać co najmniej dwa wiersze.';es_ES = 'La tabla deberá contener al menos dos líneas.';es_CO = 'La tabla deberá contener al menos dos líneas.';tr = 'Tablo en az iki satır içermelidir.';it = 'La tabella deve contenere almeno due righe.';de = 'Die Tabelle muss mindestens zwei Zeilen enthalten.'");
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
				NStr("en = 'Cannot save document ""%1""'; ru = 'Не удалось записать документ ""%1""';pl = 'Nie można zapisać dokumentu ""%1""';es_ES = 'Ha ocurrido un error al guardar el documento ""%1""';es_CO = 'Ha ocurrido un error al guardar el documento ""%1""';tr = '""%1"" belgesi saklanamıyor';it = 'Impossibile salvare il documento ""%1""';de = 'Fehler beim Speichern des Dokuments ""%1""'"),
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