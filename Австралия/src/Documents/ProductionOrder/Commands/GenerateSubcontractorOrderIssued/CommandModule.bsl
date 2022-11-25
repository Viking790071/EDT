#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	ReplenishmentMethodParameters = ReplenishmentMethodParameters(CommandParameter);
	
	DocParameters = New Structure;
	DocParameters.Insert("SubcontractorOrderIssued", CommandParameter);
	
	If ReplenishmentMethodParameters.MethodsQuantity = 1 Then
		
		DocParameters.Insert("ReplenishmentMethod", ReplenishmentMethodParameters.ReplenishmentMethod);
		GenerateProductionOrder(DocParameters);
		
	Else
		
		Notification = New NotifyDescription("ChoiceReplenishmentMethodCompletion", ThisObject, DocParameters);
		Buttons = New ValueList;
		Buttons.Add(DialogReturnCode.Yes, NStr("en = 'Assembly'; ru = 'Сборка';pl = 'Montaż';es_ES = 'Montaje';es_CO = 'Montaje';tr = 'Montaj';it = 'Assemblaggio';de = 'Montage'"));
		Buttons.Add(DialogReturnCode.No, NStr("en = 'Production'; ru = 'Производство';pl = 'Produkcja';es_ES = 'Producción';es_CO = 'Producción';tr = 'Üretim';it = 'Produzione';de = 'Produktion'"));
		Buttons.Add(DialogReturnCode.Cancel);
		ShowQueryBox(Notification, 
			NStr("en = 'The products have different replenishment methods. To generate a Production order, choose only one of the methods by clicking the button with the method name.'; ru = 'Способы пополнения номенклатуры отличаются. Чтобы создать заказ на производство, выберите только один из способов, нажав на кнопку с названием этого способа.';pl = 'Produkty mają różne sposoby uzupełniania. Aby wygenerować Zlecenie produkcyjne, wybierz tylko jeden sposób, klikając przycisk z nazwą sposobu.';es_ES = 'Los productos tienen diferentes métodos de reposición del inventario. Para generar una Orden de producción, seleccione sólo uno de los métodos haciendo clic en el botón con el nombre del método.';es_CO = 'Los productos tienen diferentes métodos de reposición del inventario. Para generar una Orden de producción, seleccione sólo uno de los métodos haciendo clic en el botón con el nombre del método.';tr = 'Ürünlerin stok yenileme yöntemi farklı. Üretim emri oluşturabilmek için, yöntem adını içeren butona tıklayarak yöntemlerden sadece birini seçin.';it = 'Gli articoli hanno differenti metodi di rifornimento. Per generare un Ordine di produzione, selezione solo uno dei metodi cliccando sul pulsante con il nome del metodo.';de = 'Die Produkte haben unterschiedliche Auffüllungsmethoden. Um einen Produktionsauftrag generieren zu können, wählen Sie eine der Methoden aus, indem Sie auf Schaltfläche mit der Methodenbezeichnung klicken.'"),
			Buttons);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Function ReplenishmentMethodParameters(SubcontractorOrderIssued)
	
	VerifiedAttributesValues = Common.ObjectAttributesValues(SubcontractorOrderIssued, "Posted, OrderState");
	Documents.SubcontractorOrderIssued.CheckEnterBasedOnSubcontractorOrder(VerifiedAttributesValues);
	
	Result = New Structure;
	Result.Insert("MethodsQuantity", 0);
	Result.Insert("ReplenishmentMethod", Enums.InventoryReplenishmentMethods.EmptyRef());
	
	Query = New Query;
	Query.Text = Documents.ProductionOrder.QueryTextFillBySubcontractorOrderIssued()
		+ DriveClientServer.GetQueryDelimeter()
		+ "SELECT
		|	ISNULL(COUNT(DISTINCT ProductsCatalog.ReplenishmentMethod), 0) AS MethodsQuantity,
		|	MIN(ProductsCatalog.ReplenishmentMethod) AS ReplenishmentMethod
		|FROM
		|	TableProduction AS SubcontractorOrderInventory
		|		INNER JOIN Catalog.Products AS ProductsCatalog
		|		ON SubcontractorOrderInventory.Products = ProductsCatalog.Ref
		|WHERE
		|	(ProductsCatalog.ReplenishmentMethod = VALUE(Enum.InventoryReplenishmentMethods.Assembly)
		|		OR ProductsCatalog.ReplenishmentMethod = VALUE(Enum.InventoryReplenishmentMethods.Production))
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT TOP 1 TRUE FROM TableProduction";
		
	Query.SetParameter("Ref", Documents.SubcontractorOrderIssued.EmptyRef());
	Query.SetParameter("BasisDocument", SubcontractorOrderIssued);
	
	ArrayMethods = New Array;
	ArrayMethods.Add(Enums.InventoryReplenishmentMethods.Assembly);
	ArrayMethods.Add(Enums.InventoryReplenishmentMethods.Processing);
	ArrayMethods.Add(Enums.InventoryReplenishmentMethods.Production);
	
	Query.SetParameter("ReplenishmentMethod", ArrayMethods);
	
	Query.Text = StrReplace(Query.Text,"FROM
	|	TableProductionPre","INTO TableProduction
	|FROM
	|	TableProductionPre");
	
	QueryResult = Query.ExecuteBatch();
	
	If QueryResult[8].IsEmpty() Then
		Raise NStr("en = 'Cannot generate a Production order. Orders have already been created for the total quantity of components specified in this Subcontractor order issued.'; ru = 'Не удалось создать заказ на производство. Заказы на количество компонентов, указанное в выданном заказе на переработку, уже созданы.';pl = 'Nie można wygenerować Zlecenie produkcyjne. Zlecenia są już utworzone dla łącznej ilości komponentów, określonej w tym Wydanym zamówieniu wykonawcy.';es_ES = 'No se ha podido generar una Orden de producción. Ya se han creado órdenes para la cantidad total de componentes especificados en esta Orden emitida del subcontratista.';es_CO = 'No se ha podido generar una Orden de producción. Ya se han creado órdenes para la cantidad total de componentes especificados en esta Orden emitida del subcontratista.';tr = 'Üretim emri oluşturulamıyor. Bu Düzenlenen alt yüklenici siparişinde belirtilen toplam malzeme miktarı için zaten emirler oluşturuldu.';it = 'Impossibile generare un Ordine di produzione. Gli ordini sono già stati creati per la quantità totale delle componenti indicate in questo Ordine subfornitura emesso.';de = 'Fehler beim Generieren eines Produktionsauftrags. Aufträge sind bereits für die Gesamtmenge von Komponenten, angegeben in diesem Subunternehmerauftrag ausgestellt, erstellt.'");
	EndIf;
	
	SelectionDetailRecords = QueryResult[7].Select();
	
	If SelectionDetailRecords.Next() Then
		FillPropertyValues(Result, SelectionDetailRecords);
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


