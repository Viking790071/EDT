#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	ReplenishmentMethodParameters = ReplenishmentMethodParameters(CommandParameter);
	
	DocParameters = New Structure;
	DocParameters.Insert("SalesOrder", CommandParameter);
	
	If ReplenishmentMethodParameters.MethodsQuantity = 0 Then
		
		CommonClientServer.MessageToUser(NStr("en = 'Cannot generate Production order from this Sales order. You can generate Production orders from Sales orders with products whose Replenishment method is Production or Assembly.'; ru = 'Не удается создать заказ на производство на основании этого заказа покупателя. Заказ на производство можно создать на основании заказа покупателя, включающего номенклатуру со способом пополнения ""Производство"" или ""Сборка"".';pl = 'Nie można wygenerować Zlecenia produkcyjnego z tego Zamówienia sprzedaży. Możesz wygenerować Zlecenia produkcyjne ze Zleceń sprzedaży, które mają sposób uzupełniania Produkcja lub Montaż.';es_ES = 'No se puede generar una Orden de producción desde esta Orden de ventas. Puede generar Órdenes de producción desde las Órdenes de venta con productos cuyo método de Reposición del inventario es Producción o Montaje.';es_CO = 'No se puede generar una Orden de producción desde esta Orden de ventas. Puede generar Órdenes de producción desde las Órdenes de venta con productos cuyo método de Reposición del inventario es Producción o Montaje.';tr = 'Bu Satış siparişinden Üretim emri oluşturulamıyor. Stok yenileme yöntemi Üretim veya Montaj olan ürünlerin bulunduğu Satış siparişlerinden Üretim emri oluşturulabilir.';it = 'Impossibile generare l''Ordine di Produzione da questo Ordine cliente. È possibile generare gli Ordini di produzione dagli Ordini cliente con gli articoli il cui metodo di Rifornimento delle scorte è Produzione o Assemblaggio.';de = 'Kann keinen Produktionsauftrag aus diesem Kundenauftrag generieren. Sie können Produktionsaufträge aus Kundenaufträgen mit der Auffüllungsmethode Produktion oder Montage generieren.'"));
		
	ElsIf ReplenishmentMethodParameters.MethodsQuantity = 1 Then
		
		DocParameters.Insert("ReplenishmentMethod", ReplenishmentMethodParameters.ReplenishmentMethod);
		GenerateProductionOrder(DocParameters);
		
	Else
		
		Notification = New NotifyDescription("ChoiceReplenishmentMethodCompletion", ThisObject, DocParameters);
		Buttons = New ValueList;
		Buttons.Add(DialogReturnCode.Yes, NStr("en = 'Assembly'; ru = 'Сборка';pl = 'Montaż';es_ES = 'Montaje';es_CO = 'Montaje';tr = 'Montaj';it = 'Assemblaggio';de = 'Montage'"));
		Buttons.Add(DialogReturnCode.No, NStr("en = 'Production'; ru = 'Производство';pl = 'Produkcja';es_ES = 'Producción';es_CO = 'Producción';tr = 'Üretim';it = 'Produzione';de = 'Produktion'"));
		Buttons.Add(DialogReturnCode.Cancel);
		ShowQueryBox(Notification, 
			NStr("en = 'The products have different replenishment methods. To generate a Production order, choose only one of the methods by clicking the button with the method name.'; ru = 'Способы пополнения номенклатуры отличаются. Чтобы создать заказ на производство, выберите только один из способов, нажав на кнопку с названием этого способа.';pl = 'Produkty mają różne sposoby uzupełniania. Aby wygenerować Zlecenie produkcyjne, wybierz tylko jeden sposób klikając przycisk z nazwą sposobu.';es_ES = 'Los productos tienen diferentes métodos de reposición del inventario. Para generar una Orden de producción, seleccione sólo uno de los métodos haciendo clic en el botón con el nombre del método.';es_CO = 'Los productos tienen diferentes métodos de reposición del inventario. Para generar una Orden de producción, seleccione sólo uno de los métodos haciendo clic en el botón con el nombre del método.';tr = 'Ürünlerin stok yenileme yöntemi farklı. Üretim emri oluşturabilmek için, yöntem adını içeren butona tıklayarak yöntemlerden sadece birini seçin.';it = 'Gli articoli hanno metodi di rifornimento delle scorte differenti. Per generare un Ordine di produzione, selezionare solo uno dei metodi cliccando sul pulsante con il nome del metodo.';de = 'Die Produkte haben unterschiedliche Auffüllungsmethoden. Um einen Produktionsauftrag generieren zu können, wählen Sie eine der Methoden aus indem Sie auf Schaltfläche mit der Methodenbezeichnung klicken.'"),
			Buttons);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Function ReplenishmentMethodParameters(SalesOrders)
	
	For Each RowOrder In SalesOrders Do
		VerifiedAttributesValues = Common.ObjectAttributesValues(RowOrder, "OperationKind, OrderState, Closed, Posted");
		Documents.SalesOrder.CheckAbilityOfEnteringBySalesOrder(RowOrder, VerifiedAttributesValues);
	EndDo;
	
	Result = New Structure;
	Result.Insert("MethodsQuantity", 0);
	Result.Insert("ReplenishmentMethod", Enums.InventoryReplenishmentMethods.EmptyRef());
	
	Query = New Query;
	Query.Text = Documents.ProductionOrder.QueryTextFillBySalesOrder()
		+ DriveClientServer.GetQueryDelimeter()
		+ "SELECT
		|	SUM(CASE
		|			WHEN SalesOrderInventory.Specification = VALUE(Catalog.BillsOfMaterials.EmptyRef)
		|				THEN CASE
		|						WHEN ProductsCatalog.ReplenishmentMethod = VALUE(Enum.InventoryReplenishmentMethods.Assembly)
		|							THEN 1
		|						ELSE 0
		|					END
		|			ELSE CASE
		|					WHEN BillsOfMaterials.OperationKind = VALUE(Enum.OperationTypesProductionOrder.Assembly)
		|						THEN 1
		|					ELSE 0
		|				END
		|		END) AS AssemblyQuantity,
		|	SUM(CASE
		|			WHEN SalesOrderInventory.Specification = VALUE(Catalog.BillsOfMaterials.EmptyRef)
		|				THEN CASE
		|						WHEN ProductsCatalog.ReplenishmentMethod = VALUE(Enum.InventoryReplenishmentMethods.Production)
		|							THEN 1
		|						ELSE 0
		|					END
		|			ELSE CASE
		|					WHEN BillsOfMaterials.OperationKind = VALUE(Enum.OperationTypesProductionOrder.Production)
		|						THEN 1
		|					ELSE 0
		|				END
		|		END) AS ProductionQuantity
		|FROM
		|	Document.SalesOrder.Inventory AS SalesOrderInventory
		|		LEFT JOIN Catalog.Products AS ProductsCatalog
		|		ON SalesOrderInventory.Products = ProductsCatalog.Ref
		|		LEFT JOIN Catalog.BillsOfMaterials AS BillsOfMaterials
		|		ON SalesOrderInventory.Specification = BillsOfMaterials.Ref
		|WHERE
		|	SalesOrderInventory.Ref IN (&BasisDocument)";
	
	Query.SetParameter("Ref", Documents.ProductionOrder.EmptyRef());
	Query.SetParameter("BasisDocument", SalesOrders);
	
	ResultsArray = Query.ExecuteBatch();
	BalanceTable = ResultsArray[0].Unload();
	BalanceTable.Indexes.Add("Products,Characteristic");
	
	If Not BalanceTable.Count() > 0 Then
		Raise NStr("en = 'Cannot generate a Production order. Orders have already been created for the total quantity of components specified in these Sales orders.'; ru = 'Не удалось создать заказ на производство. Заказы на общее количество компонентов, указанное в этих заказах покупателей, уже созданы.';pl = 'Nie można wygenerować Zlecenie produkcyjne. Zlecenia są już utworzone dla łącznej ilości komponentów, określonej w tych Zamówieniach sprzedaży.';es_ES = 'No se ha podido generar una Orden de producción. Ya se han creado órdenes para la cantidad total de componentes especificados en estas Órdenes de ventas.';es_CO = 'No se ha podido generar una Orden de producción. Ya se han creado órdenes para la cantidad total de componentes especificados en estas Órdenes de ventas.';tr = 'Üretim emri oluşturulamıyor. Bu Satış siparişlerinde belirtilen toplam malzeme miktarı için zaten emirler oluşturuldu.';it = 'Impossibile generare un Ordine di produzione. Gli ordini sono già stati creati per la quantità totale di componenti indicata in questi Ordini cliente.';de = 'Fehler beim Generieren eines Produktionsauftrags. Aufträge sind bereits für die Gesamtmenge von Komponenten, angegeben in diesem Kundenauftrag, erstellt.'");
	EndIf;
	
	SelectionDetailRecords = ResultsArray[1].Select();
	
	If SelectionDetailRecords.Next() Then
		
		If SelectionDetailRecords.AssemblyQuantity > 0 Or SelectionDetailRecords.ProductionQuantity > 0 Then
			
			If SelectionDetailRecords.AssemblyQuantity = 0 Then
				
				Result.MethodsQuantity = 1;
				Result.ReplenishmentMethod = Enums.InventoryReplenishmentMethods.Production;
				
			ElsIf SelectionDetailRecords.ProductionQuantity = 0 Then
				
				Result.MethodsQuantity = 1;
				Result.ReplenishmentMethod = Enums.InventoryReplenishmentMethods.Assembly;
				
			Else
				
				Result.MethodsQuantity = 2;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	Return Result;
	
EndFunction

&AtClient
Procedure GenerateProductionOrder(DocParameters)
	
	OpenForm("Document.ProductionOrder.ObjectForm", New Structure("Basis", DocParameters));
	
EndProcedure

&AtClient
Procedure ChoiceReplenishmentMethodCompletion(Answer, DocParameters) Export
	
	If Answer = DialogReturnCode.Cancel Then
		Return;
	EndIf;
	
	If Answer = DialogReturnCode.Yes Then
		DocParameters.Insert("ReplenishmentMethod", PredefinedValue("Enum.InventoryReplenishmentMethods.Assembly"));
	Else
		DocParameters.Insert("ReplenishmentMethod", PredefinedValue("Enum.InventoryReplenishmentMethods.Production"));
	EndIf;
	
	GenerateProductionOrder(DocParameters);
	
EndProcedure

#EndRegion


