#Region Variables

&AtServer
Var GroupByStr, TableBalance, FilterBalance, WIPProductionMethods;

#EndRegion

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Parameters.Property("ProductionOrder", ProductionOrder);
	
	If ProductionOrder.OrderState.OrderStatus = Enums.OrderStatuses.Open Then
		ErrorText = NStr("en = 'Generation from orders with ""Open"" status is not available.'; ru = 'Создание на основании заказа со статусом ""Открыт"" запрещено.';pl = 'Generowanie z zamówień ze statusem ""Otwarty"" jest niedostępne.';es_ES = 'Generación de los órdenes con el estado ""Abierto"" no se encuentra disponible.';es_CO = 'Generación de los órdenes con el estado ""Abierto"" no se encuentra disponible.';tr = 'Durumu ""Açık"" olan siparişlerden üretim yapılamaz.';it = 'La generazione degli ordini con stato ""Aperto"" non è disponibile.';de = 'Die Generierung aus Aufträgen mit dem Status ""Offen"" ist nicht verfügbar.'");
		Raise ErrorText;
	ElsIf Not AllWIPsAreAllowed() Then
		ErrorText = NStr("en = 'Cannot continue. You are trying to open a window that contains references to Work-in-progress already generated.
                          |This Work-in-progress includes the details related to a warehouse or department that you have insufficient access rights to manage. Contact the Administrator for the appropriate access rights.'; 
                          |ru = 'Не удалось открыть окно, содержащее ссылки на уже созданное Незавершенное производство.
                          |Это Незавершенное производство содержит сведения о складе или подразделении, для управления которыми у вас недостаточно прав доступа. Обратитесь к администратору за соответствующими правами доступа.';
                          |pl = 'Nie można kontynuować. Próbujesz otworzyć okno, które zawiera powiązanie z dokumentem Pracą w toku, który jest już wygenerowany.
                          |Ten dokument Praca w toku obejmuje szczegóły powiązane z magazynem lub działem, do zarządzania którym nie masz wystarczających praw dostępu. Skontaktuj się z Administratorem, aby uzyskać odpowiednie prawa dostępu.';
                          |es_ES = 'No se puede continuar. Está intentando abrir una ventana que contiene referencias a trabajos en progreso ya generados.
                          | Este trabajo en progreso incluye los detalles relacionados con un almacén o departamento que no tiene suficientes derechos de acceso para gestionar. Póngase en contacto con el administrador para obtener los derechos de acceso adecuados.';
                          |es_CO = 'No se puede continuar. Está intentando abrir una ventana que contiene referencias a trabajos en progreso ya generados.
                          | Este trabajo en progreso incluye los detalles relacionados con un almacén o departamento que no tiene suficientes derechos de acceso para gestionar. Póngase en contacto con el administrador para obtener los derechos de acceso adecuados.';
                          |tr = 'Devam edilemiyor. Zaten oluşturulmuş bir İşlem bitişi belgesine bağlantılar içeren bir pencereyi açmaya çalışıyorsunuz.
                          |Bu İşlem bitişi, gerekli erişim yetkilerine sahip olmadığınız bir ambar veya bölüm ile ilgili bilgiler içeriyor. Gerekli erişim yetkileri için Yönetici ile irtibata geçin.';
                          |it = 'Impossibile continuare. Stai cercando di aprire una finestra che contiene riferimenti a un lavori in corso già generato.
                          |Questo lavori in corso include i dettagli relativi a un magazzino o a un reparto di cui non disponi dei diritti di accesso sufficienti per gestirlo. Contatta l''amministratore per ottenere i diritti di accesso appropriati.';
                          |de = 'Fehler beim Fortfahren. Sie versuchen ein neues Fenster zu öffnen, das Referenzen auf bereits generierte Arbeit in Bearbeitung enthält.
                          |Diese Arbeit in Bearbeitung enthält die Details bezogen auf einen Lager oder eine Abteilung, auf die Sie unzureichende Zugriffsrechte für Steuern haben. Kontaktieren Sie den Administrator für die jeweiligen Zugriffsrechte.'");
		Raise ErrorText;
	EndIf;
	
	ConsiderAvailableBalance = True;
	Title = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Generate Work-in-progress for %1'; ru = 'Создать документ ""Незавершенное производство"" для %1';pl = 'Wygeneruj Pracę w toku dla %1';es_ES = 'Generar el Trabajo en progreso para %1';es_CO = 'Generar el Trabajo en progreso para %1';tr = '%1 için İşlem bitişi oluştur';it = 'Generare Lavoro in corso per %1';de = 'Arbeit in Bearbeitung für %1 generieren'"),
		ProductionOrder);
	
	SetConditionalAppearance();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If IsSubcontractorOrderBasicDocument(ProductionOrder) Or OnlyOneStageInBOMs(ProductionOrder) Then
		Items.ConsiderAvailableBalance.Visible = False;
		ConsiderAvailableBalance = False;
	EndIf;
	
	FormManagement();
	FillTree();
	ExpandAllAtClient();
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure ShowHideOperationsOnChange(Item)
	
	If Modified Then
		
		QuestionText = NStr("en = 'When you change the setting for Show / Hide operations, your changes will be discarded.
			|Do you want to continue?'; 
			|ru = 'При изменении настройки ""Отобразить/Скрыть операции"", ваши изменения будут отменены.
			|Продолжить?';
			|pl = 'Kiedy zmieniasz ustawienie dla operacji Pokaż / Ukryj, twoje zmiany zostaną odrzucone.
			|Czy chcesz kontynuować?';
			|es_ES = 'Al cambiar la configuración de las operaciones Mostrar / Ocultar, los cambios se descartarán.
			|¿Desea continuar?';
			|es_CO = 'Al cambiar la configuración de las operaciones Mostrar / Ocultar, los cambios se descartarán.
			|¿Desea continuar?';
			|tr = 'İşlemleri göster/gizle ayarını değiştirdiğinizde değişiklikleriniz kaybolacak.
			|Devam etmek istiyor musunuz?';
			|it = 'Alla modifica delle impostazioni per Mostrare / Nascondere operazioni, le modifiche saranno scartate.
			|Continuare?';
			|de = 'Beim Ändern von Einstellungen von Operationen anzeigen / ausblenden, werden die Änderungen verworfen.
			|Möchten Sie fortfahren?'");
		NotifyDescription = New NotifyDescription("ShowHideOperationsChangeQueryBox", ThisObject);
		ShowQueryBox(NotifyDescription, QuestionText, QuestionDialogMode.YesNo);
		
	Else
		
		FillTree();
		ExpandAllAtClient();
		
	EndIf;

EndProcedure

&AtClient
Procedure ShowHideOperationsChangeQueryBox(Response, AddParameters) Export
	
	If Response = DialogReturnCode.Yes Then
		
		FillTree();
		ExpandAllAtClient();
		Modified = False;
		
	Else
		
		If IsOperationsShown = 0 Then
			IsOperationsShown = 1;
		Else
			IsOperationsShown = 0;
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ConsiderAvailableBalanceOnChange(Item)
	
	FormManagement();
	
EndProcedure

#EndRegion

#Region OperationsFormTableItemsEventHandlers

&AtClient
Procedure OperationsWIPStartChoice(Item, ChoiceData, StandardProcessing)
	StandardProcessing = False;
EndProcedure

&AtClient
Procedure OperationsCreateOnChange(Item)
	
	FlagWasChanged = False;
	
	CurrentLine = Items.Operations.CurrentData;
	If CurrentLine.Create Then
		QuantityIsEmpty = ConsiderAvailableBalance And (CurrentLine.QuantityToProduce = 0);
		If QuantityIsEmpty Then
			CurrentLine.Create = False;
			CommonClientServer.MessageToUser(NStr("en = 'Quantity is required.'; ru = 'Поле ""Количество"" не заполнено.';pl = 'Wymagana jest ilość';es_ES = 'Se requiere cantidad.';es_CO = 'Se requiere cantidad.';tr = 'Miktar gerekli.';it = 'È richiesta la quantità.';de = 'Menge ist erforderlich.'"));
		Else
			Modified = True;
			FlagWasChanged = True;
		EndIf;
	Else
		FlagWasChanged = True;
	EndIf;
	
	If FlagWasChanged Then
		
		If CurrentLine.Create Then
			SetFlagForAllHigherRankingLines(CurrentLine);
		Else
			ClearFlagForAllLowerRankingLines(CurrentLine);
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OperationsQuantityToProduceOnChange(Item)
	
	Modified = True;
	CurrentLine = Items.Operations.CurrentData;
	If CurrentLine.QuantityToProduce = 0 Then
		If CurrentLine.Create And Not ValueIsFilled(CurrentLine.WIP) Then
			CurrentLine.Create = False;
		EndIf;
	ElsIf CurrentLine.QuantityToProduce > CurrentLine.QuantityByBOM Then
		CurrentLine.QuantityToProduce = CurrentLine.QuantityByBOM;
		CommonClientServer.MessageToUser(NStr("en = 'The new quantity cannot be greater than Quantity by BOM.'; ru = 'Новое количество не может превышать Количество по спецификации.';pl = 'Nowa ilość nie może być większa niż Ilość według Specyfikacji materiałowej.';es_ES = 'La nueva cantidad no puede ser mayor que Cantidad por lista de materiales.';es_CO = 'La nueva cantidad no puede ser mayor que Cantidad por lista de materiales.';tr = 'Yeni miktar, Ürün reçetesi miktarından büyük olamaz.';it = 'La nuova quantità non può essere maggiore della Quantità nella Distinta Base.';de = 'Die neue Menge darf nicht über die Menge bei der Stückliste liegen.'"));
	EndIf;
	
	RecalculateQuantityToProduce(CurrentLine);
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure ExpandAll(Command)
	
	ExpandAllAtClient();
	
EndProcedure

&AtClient
Procedure CollapseAll(Command)
	
	CollapseRecursively(Operations.GetItems());
	
EndProcedure

&AtClient
Procedure CheckAll(Command)
	
	SetCreateValueForAllItems(True);
	
EndProcedure

&AtClient
Procedure UncheckAll(Command)
	
	SetCreateValueForAllItems(False);
	
EndProcedure

&AtClient
Procedure CreateWIPs(Command)
	
	TimeConsumingOperation = ExecuteTimeConsumingOperationAtServer();
	
	IdleParameters = TimeConsumingOperationsClient.IdleParameters(ThisObject);
	IdleParameters.OutputIdleWindow			= True;
	IdleParameters.OutputProgressBar		= True;
	IdleParameters.OutputMessages			= True;
	IdleParameters.UserNotification.Show	= True;
	IdleParameters.MessageText				= NStr("en = 'Work-in-progress is being generated'; ru = 'Идет создание документа ""Незавершенное производство""';pl = 'Trwa generowanie pracy w toku';es_ES = 'Se está generando el trabajo en progreso';es_CO = 'Se está generando el trabajo en progreso';tr = 'İşlem bitişi oluşturuluyor';it = 'Lavoro in corso in creazione';de = 'Arbeit in Bearbeitung wird generiert'");
	
	CompletionNotification = New NotifyDescription(
		"TimeConsumingOperationEnd",
		ThisObject);
		
	TimeConsumingOperationsClient.WaitForCompletion(TimeConsumingOperation, CompletionNotification, IdleParameters);
	
EndProcedure

&AtServer
Function ExecuteTimeConsumingOperationAtServer()
	
	ProcedureParameters = New Structure;
	ProcedureParameters.Insert("Operations", FormDataToValue(Operations, Type("ValueTree")));
	ProcedureParameters.Insert("IsOperationsShown", IsOperationsShown);
	ProcedureParameters.Insert("ProductionOrder", ProductionOrder);
	ProcedureParameters.Insert("ConsiderAvailableBalance", ConsiderAvailableBalance);
	
	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(UUID);
	ExecutionParameters.BackgroundJobDescription = NStr("en = 'Work-in-progress is being generated'; ru = 'Идет создание документа ""Незавершенное производство""';pl = 'Trwa generowanie pracy w toku';es_ES = 'Se está generando el trabajo en progreso';es_CO = 'Se está generando el trabajo en progreso';tr = 'İşlem bitişi oluşturuluyor';it = 'Lavoro in corso in creazione';de = 'Arbeit in Bearbeitung wird generiert'");
	ExecutionParameters.WaitForCompletion = 0;
	
	Return TimeConsumingOperations.ExecuteInBackground(
		"Documents.ProductionOrder.GenerateWIPsInBackground",
		ProcedureParameters,
		ExecutionParameters);
	
EndFunction

&AtClient
Procedure TimeConsumingOperationEnd(Result, AdditionalParameters) Export
	
	If Result = Undefined Then
		Return;
	EndIf;
	
	If Result.Status = "Error" Then
		
		CommonClientServer.MessageToUser(
			StrTemplate(NStr("en = 'Can''t generate Work-in-progress: %1'; ru = 'Не удалось создать документ ""Незавершенное производство"": %1';pl = 'Nie można wygenerować pracy w toku: %1';es_ES = 'No se ha podido generar el trabajo en progreso: %1';es_CO = 'No se ha podido generar el trabajo en progreso: %1';tr = 'İşlem bitişi oluşturulamadı: %1';it = 'Impossibile creare Lavoro in corso: %1';de = 'Fehler beim Generieren der Arbeit in Bearbeitung: %1'"), Result.BriefErrorPresentation));
		Return;
		
	Else
		
		LoadOperationsResult(Result.ResultAddress);
		Items.Operations.Refresh();
		ExpandAllAtClient();
		Notify("RefreshProductionOrderQueue");
		Modified = False;
	
	EndIf;
	
EndProcedure

&AtServer
Function LoadOperationsResult(ResultAddress)
	ValueToFormData(GetFromTempStorage(ResultAddress), Operations);
EndFunction

&AtClient
Procedure Refresh(Command)
	
	If Modified Then
		
		QuestionText = NStr("en = 'Your changes will be discarded. Do you want to continue?'; ru = 'Ваши изменения будут отменены. Продолжить?';pl = 'Twoje zmiany zostaną odrzucone. Czy chcesz kontynuować?';es_ES = 'Sus cambios serán descartados. ¿Quiere continuar?';es_CO = 'Sus cambios serán descartados. ¿Quiere continuar?';tr = 'Değişiklikleriniz kaybolacak. Devam etmek istiyor musunuz?';it = 'Le modifiche andranno perse. Continuare?';de = 'Ihre Änderungen werden verworfen. Möchten Sie fortfahren?'");
		NotifyDescription = New NotifyDescription("AfterRefreshQueryClose", ThisObject);
		ShowQueryBox(NotifyDescription, QuestionText, QuestionDialogMode.YesNo);
		
	Else
		
		FillTree();
		ExpandAllAtClient();
		Modified = False;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterRefreshQueryClose(Result, Parameters) Export
	
	If Result = DialogReturnCode.Yes Then
		
		FillTree();
		ExpandAllAtClient();
		Modified = False;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtServerNoContext
Function IsSubcontractorOrderBasicDocument(ProductionOrder)
	
	BasisDocument = Common.ObjectAttributeValue(ProductionOrder, "BasisDocument");
	Return (TypeOf(BasisDocument) = Type("DocumentRef.SubcontractorOrderReceived"));
	
EndFunction

&AtServerNoContext
Function OnlyOneStageInBOMs(ProductionOrder)
	
	Query = New Query;
	Query.Text =
	"SELECT DISTINCT
	|	ProductionOrderProducts.Specification AS Specification
	|INTO TT_BOMs
	|FROM
	|	Document.ProductionOrder.Products AS ProductionOrderProducts
	|WHERE
	|	ProductionOrderProducts.Ref = &ProductionOrder
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	BillsOfMaterialsContent.Ref AS Ref
	|FROM
	|	TT_BOMs AS TT_BOMs
	|		INNER JOIN Catalog.BillsOfMaterials.Content AS BillsOfMaterialsContent
	|		ON TT_BOMs.Specification = BillsOfMaterialsContent.Ref
	|WHERE
	|	BillsOfMaterialsContent.ManufacturedInProcess";
	
	Query.SetParameter("ProductionOrder", ProductionOrder);
	
	QueryResult = Query.Execute();
	
	Return QueryResult.IsEmpty();
	
EndFunction

&AtClient
Procedure FormManagement()
	
	Items.OperationsGroupQuantity.Visible = ConsiderAvailableBalance;
	
EndProcedure

&AtClient
Procedure ExpandAllAtClient()
	
	LevelProducts = Operations.GetItems();
	For Each LevelProducts_Item In LevelProducts Do
		Items.Operations.Expand(LevelProducts_Item.GetID(), True);
	EndDo;
	
EndProcedure

&AtServer
Procedure FillTree()
	
	TableToFillTree = TableToFillTree(ProductionOrder, IsOperationsShown);
	
	TableBalance = AvailableBalanceTable(
		Common.ObjectAttributeValue(ProductionOrder, "Company"),
		TableToFillTree.UnloadColumn("SemifinishedProducts"));
	FilterBalance = New Structure("Products, Characteristic");
	
	Tree = FormAttributeToValue("Operations");
	
	Tree.Rows.Clear();
	
	GroupByStr = "Products, Characteristic, Specification, ParentActivity, ParentActivityNumber, ParentConnectionKey,
				|Level, SemifinishedProducts, SemifinishedCharacteristic, ActivitySpecification, HierarchyItem,
				|BOMHeaderQuantity, BOMQuantity, BOMCalculationMethod, ProductionMethod";
	
	ValueTableProducts = ProductionOrder.Products.Unload();
	ValueTableProducts.GroupBy("Products, ProductsType, Characteristic, MeasurementUnit, Specification",
		"Quantity");
	
	InHouseMethod = Enums.ProductionMethods.InHouseProduction;
	WIPProductionMethods = GetProductionMethods(TableToFillTree.UnloadColumn("WIP"));
	
	For Each Product In ValueTableProducts Do
		
		LineProduct = Tree.Rows.Add();
		FillPropertyValues(LineProduct, Product);
		LineProduct.SemifinishedProducts = LineProduct.Products;
		LineProduct.SemifinishedCharacteristic = LineProduct.Characteristic;
		LineProduct.ActivitySpecification = Product.Specification;
		
		LineProductFilter = New Structure("Products, Characteristic, Specification, ActivitySpecification");
		FillPropertyValues(LineProductFilter, Product);
		LineProductFilter.ActivitySpecification = Product.Specification;
		
		Level0Rows = TableToFillTree.FindRows(LineProductFilter);
		
		Level0Products = TableToFillTree.Copy(LineProductFilter);
		Level0Products.GroupBy(GroupByStr);
		If Level0Products.Count() Then
			FillPropertyValues(LineProduct,
				Level0Products[0],
				"HierarchyItem, BOMHeaderQuantity, BOMQuantity, BOMCalculationMethod");
		EndIf;
		
		LineProduct.QuantityByBOM = ?(
			TypeOf(Product.MeasurementUnit) = Type("CatalogRef.UOM"),
			Product.Quantity * Common.ObjectAttributeValue(Product.MeasurementUnit, "Factor"),
			Product.Quantity);
		LineProduct.QuantityInOrder = LineProduct.QuantityByBOM;
		LineProduct.QuantityToProduce = LineProduct.QuantityByBOM;
		
		LineProduct.RoundedQuantityByBOM = LineProduct.QuantityToProduce;
		If LineProduct.BOMHeaderQuantity > 1 
			And LineProduct.QuantityToProduce % LineProduct.BOMHeaderQuantity > 0 Then
			
			LineProduct.RoundedQuantityByBOM = (Int(LineProduct.QuantityToProduce / LineProduct.BOMHeaderQuantity) + 1)
				* LineProduct.BOMHeaderQuantity;
			
		EndIf;
		
		LineProductFilter.Insert("OutputWIP", True);
		Level0RowsOutputWIP = TableToFillTree.FindRows(LineProductFilter);
		If Level0RowsOutputWIP.Count() Then
			
			LineProduct.WIP = Level0RowsOutputWIP[0].WIP;
			
			LineWIP = WIPProductionMethods.Find(LineProduct.WIP,"WIP");
			If LineWIP <> Undefined And ValueIsFilled(LineWIP.ProductionMethod) Then
				LineProduct.ProductionMethod = LineWIP.ProductionMethod;
			EndIf;
		EndIf;
		
		If Not ValueIsFilled(LineProduct.ProductionMethod) Then
			LineProduct.ProductionMethod = InHouseMethod;
		EndIf;
		
		For Each Row_Level0 In Level0Rows Do
			
			If IsOperationsShown Then
				Line0 = LineProduct.Rows.Add();
				FillPropertyValues(Line0, Row_Level0);
				
				Line0.ProductionMethod = Undefined;
			Else
				Line0 = LineProduct;
			EndIf;
			
			Line0Filter = New Structure("Products, Characteristic, Specification, ParentActivity, ParentActivityNumber, ParentConnectionKey, Level");
			FillPropertyValues(Line0Filter, Row_Level0, "Products, Characteristic");
			Line0Filter.Specification 			= Row_Level0.ActivitySpecification;
			Line0Filter.ParentActivity 			= Row_Level0.Activity;
			Line0Filter.ParentActivityNumber 	= Row_Level0.ActivityNumber;
			Line0Filter.ParentConnectionKey 	= Row_Level0.ConnectionKey;
			Line0Filter.Level 					= 1;
			
			AllLevel1Rows = TableToFillTree.Copy(Line0Filter);
			
			Level1Products = TableToFillTree.Copy(Line0Filter);
			Level1Products.GroupBy(GroupByStr);
			
			For Each Product_Level1 In Level1Products Do
				
				Product_Line1 = Line0.Rows.Add();
				FillPropertyValues(Product_Line1, Product_Level1);
				
				If Product_Level1.BOMCalculationMethod = Enums.BOMContentCalculationMethod.Proportional Then
					Product_Line1.QuantityByBOM =
						Product_Line1.BOMQuantity / LineProduct.BOMHeaderQuantity * LineProduct.QuantityByBOM;
				Else
					Product_Line1.QuantityByBOM =
						Product_Line1.BOMQuantity / LineProduct.BOMHeaderQuantity * LineProduct.RoundedQuantityByBOM;
				EndIf;
				
				Product_Line1.QuantityInOrder = Product_Line1.QuantityByBOM;
				
				FilterBalance.Products = Product_Level1.SemifinishedProducts;
				FilterBalance.Characteristic = Product_Level1.SemifinishedCharacteristic;
				BalanceRows = TableBalance.FindRows(FilterBalance);
				For Each BalanceRow In BalanceRows Do
					Product_Line1.QuantityAvailable = Product_Line1.QuantityAvailable + BalanceRow.QuantityBalance;
				EndDo;
				If Product_Line1.QuantityAvailable < 0 Then
					Product_Line1.QuantityToProduce = Product_Line1.QuantityByBOM;
				Else
					Product_Line1.QuantityToProduce = ?(
						Product_Line1.QuantityAvailable >= Product_Line1.QuantityByBOM,
						0,
						Product_Line1.QuantityByBOM - Product_Line1.QuantityAvailable)
				EndIf;
				
				Product_Line1.RoundedQuantityByBOM = Product_Line1.QuantityToProduce;
				If Product_Line1.BOMHeaderQuantity > 1 
					And Product_Line1.QuantityToProduce % Product_Line1.BOMHeaderQuantity > 0 Then
					
					Product_Line1.RoundedQuantityByBOM = (Int(Product_Line1.QuantityToProduce / Product_Line1.BOMHeaderQuantity) + 1)
						* Product_Line1.BOMHeaderQuantity;
					
				EndIf;
				
				Product_Line1Filter = New Structure("SemifinishedProducts, SemifinishedCharacteristic");
				FillPropertyValues(Product_Line1Filter, Product_Line1);
				
				Level1Rows = AllLevel1Rows.Copy(Product_Line1Filter);
				
				OutputWIP_Line1Filter = New Structure("OutputWIP", True);
				Level1RowsOutputWIP = Level1Rows.FindRows(OutputWIP_Line1Filter);
				If Level1RowsOutputWIP.Count() Then
					Product_Line1.WIP = Level1RowsOutputWIP[0].WIP;
					
					LineWIP = WIPProductionMethods.Find(Product_Line1.WIP,"WIP");
					
					If LineWIP <> Undefined And ValueIsFilled(LineWIP.ProductionMethod) Then
						Product_Line1.ProductionMethod = LineWIP.ProductionMethod;
					EndIf;
					
				EndIf;
				
				For Each Row_Level1 In Level1Rows Do
					
					If IsOperationsShown Then
						Line1 = Product_Line1.Rows.Add();
						FillPropertyValues(Line1, Row_Level1);
						
						Line1.ProductionMethod = Undefined;
					Else
						Line1 = Product_Line1;
					EndIf;
					
					Line1Filter = New Structure("Products, Characteristic, Specification, ParentActivity, ParentActivityNumber, ParentConnectionKey, Level");
					FillPropertyValues(Line1Filter, Row_Level1, "Products, Characteristic");
					Line1Filter.Specification 			= Row_Level1.ActivitySpecification;
					Line1Filter.ParentActivity 			= Row_Level1.Activity;
					Line1Filter.ParentActivityNumber 	= Row_Level1.ActivityNumber;
					Line1Filter.ParentConnectionKey 	= Row_Level1.ConnectionKey;
					Line1Filter.Level 					= 2;
					
					AddLevelRows(Line1Filter, TableToFillTree, Line1, Product_Line1, 3);
					
				EndDo;
				
			EndDo;
			
		EndDo;
		
	EndDo;
	
	ValueToFormAttribute(Tree, "Operations");
	
EndProcedure

&AtServer
Procedure AddLevelRows(LineFilter, TableToFillTree, TreeRow, PrevProduct_Line, Val Level)
	
	AllLevelRows = TableToFillTree.Copy(LineFilter);
	
	LevelProducts = TableToFillTree.Copy(LineFilter);
	LevelProducts.GroupBy(GroupByStr);
	
	For Each Product_Level In LevelProducts Do
		
		Product_Line = TreeRow.Rows.Add();
		FillPropertyValues(Product_Line, Product_Level);
		
		If Product_Line.BOMCalculationMethod = Enums.BOMContentCalculationMethod.Proportional Then
			Product_Line.QuantityByBOM = Product_Line.BOMQuantity
				/ PrevProduct_Line.BOMHeaderQuantity
				* PrevProduct_Line.QuantityToProduce;
		Else
			Product_Line.QuantityByBOM = Product_Line.BOMQuantity
				/ PrevProduct_Line.BOMHeaderQuantity
				* PrevProduct_Line.RoundedQuantityByBOM;
		EndIf;
		
		If Product_Line.BOMCalculationMethod = Enums.BOMContentCalculationMethod.Proportional Then
			
			Product_Line.QuantityInOrder = Product_Line.BOMQuantity
				/ PrevProduct_Line.BOMHeaderQuantity
				* PrevProduct_Line.QuantityByBOM;
			
		Else
			
			RoundedQuantityByBOM = PrevProduct_Line.QuantityInOrder;
			If PrevProduct_Line.BOMHeaderQuantity > 1
				And PrevProduct_Line.QuantityInOrder % PrevProduct_Line.BOMHeaderQuantity > 0 Then
				
				RoundedQuantityByBOM = (Int(PrevProduct_Line.QuantityInOrder / PrevProduct_Line.BOMHeaderQuantity) + 1)
					* PrevProduct_Line.BOMHeaderQuantity;
				
			EndIf;
			
			Product_Line.QuantityInOrder = Product_Line.BOMQuantity
				/ PrevProduct_Line.BOMHeaderQuantity
				* RoundedQuantityByBOM;
			
		EndIf;
		
		FilterBalance.Products = Product_Line.SemifinishedProducts;
		FilterBalance.Characteristic = Product_Line.SemifinishedCharacteristic;
		BalanceRows = TableBalance.FindRows(FilterBalance);
		
		For Each BalanceRow In BalanceRows Do
			Product_Line.QuantityAvailable = Product_Line.QuantityAvailable + BalanceRow.QuantityBalance;
		EndDo;
		
		If Product_Line.QuantityAvailable < 0 Then
			Product_Line.QuantityToProduce = Product_Line.QuantityByBOM;
		Else
			Product_Line.QuantityToProduce = ?(Product_Line.QuantityAvailable >= Product_Line.QuantityByBOM,
				0,
				Product_Line.QuantityByBOM - Product_Line.QuantityAvailable)
		EndIf;
		
		Product_Line.RoundedQuantityByBOM = Product_Line.QuantityToProduce;
		If Product_Line.BOMHeaderQuantity > 1 
			And Product_Line.QuantityToProduce % Product_Line.BOMHeaderQuantity > 0 Then
			
			Product_Line.RoundedQuantityByBOM = (Int(Product_Line.QuantityToProduce / Product_Line.BOMHeaderQuantity) + 1)
				* Product_Line.BOMHeaderQuantity;
			
		EndIf;
		
		Product_LineFilter = New Structure("SemifinishedProducts, SemifinishedCharacteristic");
		FillPropertyValues(Product_LineFilter, Product_Level);
		
		LevelRows = AllLevelRows.Copy(Product_LineFilter);
		
		LevelRowsOutputWIP = LevelRows.FindRows(New Structure("OutputWIP", True));
		If LevelRowsOutputWIP.Count() Then
			Product_Line.WIP = LevelRowsOutputWIP[0].WIP;
			
			LineWIP = WIPProductionMethods.Find(Product_Line.WIP,"WIP");
			
			If LineWIP <> Undefined And ValueIsFilled(LineWIP.ProductionMethod) Then
				Product_Line.ProductionMethod = LineWIP.ProductionMethod;
			EndIf;
		EndIf;
		
		For Each Row_Level In LevelRows Do
			
			If IsOperationsShown Then
				NewTreeRow = Product_Line.Rows.Add();
				FillPropertyValues(NewTreeRow, Row_Level);
				NewTreeRow.ProductionMethod = Undefined;
			Else
				NewTreeRow = Product_Line;
			EndIf;
			
			LineFilter = New Structure("Products, Characteristic, Specification, ParentActivity, ParentActivityNumber, ParentConnectionKey, Level");
			LineFilter.Products				= Row_Level.Products;
			LineFilter.Characteristic		= Row_Level.Characteristic;
			LineFilter.Specification		= Row_Level.ActivitySpecification;
			LineFilter.ParentActivity		= Row_Level.Activity;
			LineFilter.ParentActivityNumber	= Row_Level.ActivityNumber;
			LineFilter.ParentConnectionKey	= Row_Level.ConnectionKey;
			LineFilter.Level				= Level;
			
			AddLevelRows(LineFilter, TableToFillTree, NewTreeRow, Product_Line, Level+1);
			
		EndDo;
		
	EndDo;
	
EndProcedure

&AtClient
Procedure RecalculateQuantityToProduce(CurrentLine)
	
	CurrentLine.RoundedQuantityByBOM = CurrentLine.QuantityToProduce;
	If CurrentLine.BOMHeaderQuantity > 1 
		And CurrentLine.QuantityToProduce % CurrentLine.BOMHeaderQuantity > 0 Then
		
		CurrentLine.RoundedQuantityByBOM = (Int(CurrentLine.QuantityToProduce / CurrentLine.BOMHeaderQuantity) + 1)
			* CurrentLine.BOMHeaderQuantity;
		
	EndIf;
	
	RecalculateQuantityToProduceRecursive(CurrentLine.GetItems(), CurrentLine);
	
EndProcedure

&AtClient
Procedure RecalculateQuantityToProduceRecursive(Level, CurrentLine)
	
	For Each Level_Item In Level Do
		
		If Not ValueIsFilled(Level_Item.Activity) Then
			
			If Level_Item.BOMCalculationMethod = PredefinedValue("Enum.BOMContentCalculationMethod.Proportional") Then
				Level_Item.QuantityByBOM = Level_Item.BOMQuantity
					/ CurrentLine.BOMHeaderQuantity
					* CurrentLine.QuantityToProduce;
			Else
				Level_Item.QuantityByBOM = Level_Item.BOMQuantity
					/ CurrentLine.BOMHeaderQuantity
					* CurrentLine.RoundedQuantityByBOM;
			EndIf;
			
			If Level_Item.QuantityAvailable < 0 Then
				Level_Item.QuantityToProduce = Level_Item.QuantityByBOM;
			Else
				Level_Item.QuantityToProduce = ?(Level_Item.QuantityAvailable >= Level_Item.QuantityByBOM,
					0,
					Level_Item.QuantityByBOM - Level_Item.QuantityAvailable)
			EndIf;
			
			Level_Item.RoundedQuantityByBOM = Level_Item.QuantityToProduce;
			If Level_Item.BOMHeaderQuantity > 1
				And Level_Item.QuantityToProduce % Level_Item.BOMHeaderQuantity > 0 Then
				
				Level_Item.RoundedQuantityByBOM = (Int(Level_Item.QuantityToProduce / Level_Item.BOMHeaderQuantity) + 1)
					* Level_Item.BOMHeaderQuantity;
				
			EndIf;
			
			If Level_Item.QuantityToProduce = 0 Then
				If Level_Item.Create And Not ValueIsFilled(Level_Item.WIP) Then
					Level_Item.Create = False;
				EndIf;
			EndIf;
			
		EndIf;
		
		RecalculateQuantityToProduceRecursive(Level_Item.GetItems(), CurrentLine)
		
	EndDo;
	
EndProcedure

&AtServerNoContext
Function TableToFillTree(ProductionOrder, IsOperationsShown)
	
	MaxNumberOfBOMLevels = Constants.MaxNumberOfBOMLevels.Get();
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	FinishedProducts.Products AS Products,
	|	FinishedProducts.Characteristic AS Characteristic,
	|	FinishedProducts.Specification AS Specification,
	|	FinishedProducts.Products AS SemifinishedProducts,
	|	FinishedProducts.Characteristic AS SemifinishedCharacteristic,
	|	BillsOfMaterialsHierarchy.Ref AS HierarchyItem,
	|	VALUE(Catalog.ManufacturingActivities.EmptyRef) AS ParentActivity,
	|	-1 AS ParentActivityNumber,
	|	-1 AS ParentConnectionKey,
	|	BillsOfMaterialsOperations.ConnectionKey AS ConnectionKey,
	|	BillsOfMaterialsOperations.ActivityNumber AS ActivityNumber,
	|	BillsOfMaterialsOperations.Activity AS Activity,
	|	FinishedProducts.Specification AS ActivitySpecification,
	|	BillsOfMaterialsContent.Specification AS ChildSpecification,
	|	BillsOfMaterialsContent.Products AS ActivityProducts,
	|	BillsOfMaterialsContent.Characteristic AS ActivityCharacteristic,
	|	BillsOfMaterialsOperations.Ref.Quantity AS BOMHeaderQuantity,
	|	1 AS BOMQuantity,
	|	VALUE(Enum.BOMContentCalculationMethod.Proportional) AS BOMCalculationMethod,
	|	CASE
	|		WHEN VALUETYPE(BillsOfMaterialsContent.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN BillsOfMaterialsContent.Quantity
	|		ELSE BillsOfMaterialsContent.Quantity * BillsOfMaterialsContent.MeasurementUnit.Factor
	|	END AS SemifinishedProductQuantity,
	|	BillsOfMaterialsContent.CalculationMethod AS SemifinishedProductCalculationMethod
	|INTO LevelTable0
	|FROM
	|	Document.ProductionOrder.Products AS FinishedProducts
	|		INNER JOIN Catalog.BillsOfMaterials.Operations AS BillsOfMaterialsOperations
	|		ON FinishedProducts.Specification = BillsOfMaterialsOperations.Ref
	|		INNER JOIN Catalog.BillsOfMaterialsHierarchy AS BillsOfMaterialsHierarchy
	|		ON FinishedProducts.Specification = BillsOfMaterialsHierarchy.Specification
	|			AND (BillsOfMaterialsHierarchy.Parent = VALUE(Catalog.BillsOfMaterialsHierarchy.EmptyRef))
	|			AND (NOT BillsOfMaterialsHierarchy.DeletionMark)
	|		LEFT JOIN Catalog.BillsOfMaterials.Content AS BillsOfMaterialsContent
	|		ON (BillsOfMaterialsOperations.Ref = BillsOfMaterialsContent.Ref)
	|			AND (BillsOfMaterialsOperations.ConnectionKey = BillsOfMaterialsContent.ActivityConnectionKey)
	|			AND (BillsOfMaterialsContent.ManufacturedInProcess)
	|WHERE
	|	FinishedProducts.Ref = &ProductionOrder
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ManufacturingOperationActivities.Output AS Output,
	|	ManufacturingOperationActivities.Activity AS Activity,
	|	ManufacturingOperationActivities.ActivityNumber AS ActivityNumber,
	|	ManufacturingOperationActivities.ConnectionKey AS ConnectionKey,
	|	ManufacturingOperation.Specification AS Specification,
	|	ManufacturingOperation.Ref AS WIP,
	|	ManufacturingOperation.BOMHierarchyItem AS HierarchyItem,
	|	ManufacturingOperation.Products AS Products,
	|	ManufacturingOperation.Characteristic AS Characteristic
	|INTO CreatedWIP
	|FROM
	|	Document.ManufacturingOperation.Activities AS ManufacturingOperationActivities
	|		LEFT JOIN Document.ManufacturingOperation AS ManufacturingOperation
	|		ON ManufacturingOperationActivities.Ref = ManufacturingOperation.Ref
	|WHERE
	|	ManufacturingOperation.Posted
	|	AND ManufacturingOperation.BasisDocument = &ProductionOrder
	|	AND &IsOutputWIP";
	
	QueryTextFragment1 = "";
	QueryTextFragment2 = DriveClientServer.GetQueryDelimeter() + "
		|SELECT
		|	LevelTable.Products AS Products,
		|	LevelTable.Characteristic AS Characteristic,
		|	LevelTable.ActivityNumber AS ActivityNumber,
		|	LevelTable.ConnectionKey AS ConnectionKey,
		|	LevelTable.Activity AS Activity,
		|	LevelTable.ParentActivity AS ParentActivity,
		|	LevelTable.ParentActivityNumber AS ParentActivityNumber,
		|	LevelTable.ParentConnectionKey AS ParentConnectionKey,
		|	LevelTable.Specification AS Specification,
		|	LevelTable.ActivitySpecification AS ActivitySpecification,
		|	LevelTable.SemifinishedProducts AS SemifinishedProducts,
		|	LevelTable.SemifinishedCharacteristic AS SemifinishedCharacteristic,
		|	LevelTable.HierarchyItem AS HierarchyItem,
		|	LevelTable.BOMHeaderQuantity AS BOMHeaderQuantity,
		|	LevelTable.BOMQuantity AS BOMQuantity,
		|	LevelTable.BOMCalculationMethod AS BOMCalculationMethod,
		|	0 AS Level
		|INTO AllLevelTable
		|FROM
		|	LevelTable0 AS LevelTable
		|
		|GROUP BY
		|	LevelTable.Products,
		|	LevelTable.Characteristic,
		|	LevelTable.ConnectionKey,
		|	LevelTable.ActivityNumber,
		|	LevelTable.Activity,
		|	LevelTable.ParentActivity,
		|	LevelTable.ParentActivityNumber,
		|	LevelTable.ParentConnectionKey,
		|	LevelTable.Specification,
		|	LevelTable.ActivitySpecification,
		|	LevelTable.SemifinishedProducts,
		|	LevelTable.SemifinishedCharacteristic,
		|	LevelTable.HierarchyItem,
		|	LevelTable.BOMHeaderQuantity,
		|	LevelTable.BOMQuantity,
		|	LevelTable.BOMCalculationMethod";
	
	For i = 1 To MaxNumberOfBOMLevels-1 Do
		
		Text1 = DriveClientServer.GetQueryDelimeter() + "
			|SELECT
			|	PrevLevelTable.Products AS Products,
			|	PrevLevelTable.Characteristic AS Characteristic,
			|	PrevLevelTable.ActivitySpecification AS Specification,
			|	PrevLevelTable.ChildSpecification AS ActivitySpecification,
			|	PrevLevelTable.Activity AS ParentActivity,
			|	PrevLevelTable.ActivityNumber AS ParentActivityNumber,
			|	PrevLevelTable.ConnectionKey AS ParentConnectionKey,
			|	PrevLevelTable.ActivityProducts AS SemifinishedProducts,
			|	PrevLevelTable.ActivityCharacteristic AS SemifinishedCharacteristic,
			|	BillsOfMaterialsHierarchy.Ref AS HierarchyItem,
			|	PrevLevelTable.SemifinishedProductQuantity AS BOMQuantity,
			|	PrevLevelTable.SemifinishedProductCalculationMethod AS BOMCalculationMethod,
			|	BillsOfMaterialsContent.Specification AS ChildSpecification,
			|	BillsOfMaterialsOperations.ConnectionKey AS ConnectionKey,
			|	BillsOfMaterialsOperations.ActivityNumber AS ActivityNumber,
			|	BillsOfMaterialsOperations.Activity AS Activity,
			|	BillsOfMaterialsContent.Products AS ActivityProducts,
			|	BillsOfMaterialsContent.Characteristic AS ActivityCharacteristic,
			|	BillsOfMaterialsOperations.Ref.Quantity AS BOMHeaderQuantity,
			|	CASE
			|		WHEN VALUETYPE(BillsOfMaterialsContent.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
			|			THEN BillsOfMaterialsContent.Quantity
			|		ELSE BillsOfMaterialsContent.Quantity * BillsOfMaterialsContent.MeasurementUnit.Factor
			|	END AS SemifinishedProductQuantity,
			|	BillsOfMaterialsContent.CalculationMethod AS SemifinishedProductCalculationMethod
			|INTO %1
			|FROM
			|	%2 AS PrevLevelTable
			|		INNER JOIN Catalog.BillsOfMaterials.Operations AS BillsOfMaterialsOperations
			|		ON PrevLevelTable.ChildSpecification = BillsOfMaterialsOperations.Ref
			|		INNER JOIN Catalog.BillsOfMaterialsHierarchy AS BillsOfMaterialsHierarchy
			|		ON PrevLevelTable.ChildSpecification = BillsOfMaterialsHierarchy.Specification
			|			AND PrevLevelTable.HierarchyItem = BillsOfMaterialsHierarchy.Parent
			|			AND (NOT BillsOfMaterialsHierarchy.DeletionMark)
			|		LEFT JOIN Catalog.BillsOfMaterials.Content AS BillsOfMaterialsContent
			|		ON (BillsOfMaterialsOperations.Ref = BillsOfMaterialsContent.Ref)
			|			AND (BillsOfMaterialsOperations.ConnectionKey = BillsOfMaterialsContent.ActivityConnectionKey)
			|			AND (BillsOfMaterialsContent.ManufacturedInProcess)";
		
		QueryTextFragment1 = QueryTextFragment1 + StrTemplate(Text1, "LevelTable" + String(i), "LevelTable" + String(i-1));
		
		Text2 = DriveClientServer.GetQueryUnion() + "
			|SELECT
			|	LevelTable.Products AS Products,
			|	LevelTable.Characteristic AS Characteristic,
			|	LevelTable.ActivityNumber AS ActivityNumber,
			|	LevelTable.ConnectionKey AS ConnectionKey,
			|	LevelTable.Activity AS Activity,
			|	LevelTable.ParentActivity AS ParentActivity,
			|	LevelTable.ParentActivityNumber AS ParentActivityNumber,
			|	LevelTable.ParentConnectionKey AS ParentConnectionKey,
			|	LevelTable.Specification AS Specification,
			|	LevelTable.ActivitySpecification AS ActivitySpecification,
			|	LevelTable.SemifinishedProducts AS SemifinishedProducts,
			|	LevelTable.SemifinishedCharacteristic AS SemifinishedCharacteristic,
			|	LevelTable.HierarchyItem AS HierarchyItem,
			|	LevelTable.BOMHeaderQuantity AS BOMHeaderQuantity,
			|	LevelTable.BOMQuantity AS BOMQuantity,
			|	LevelTable.BOMCalculationMethod AS BOMCalculationMethod,
			|	%2
			|FROM
			|	%1 AS LevelTable
			|
			|GROUP BY
			|	LevelTable.Products,
			|	LevelTable.Characteristic,
			|	LevelTable.ConnectionKey,
			|	LevelTable.ActivityNumber,
			|	LevelTable.Activity,
			|	LevelTable.ParentActivity,
			|	LevelTable.ParentActivityNumber,
			|	LevelTable.ParentConnectionKey,
			|	LevelTable.Specification,
			|	LevelTable.ActivitySpecification,
			|	LevelTable.SemifinishedProducts,
			|	LevelTable.SemifinishedCharacteristic,
			|	LevelTable.HierarchyItem,
			|	LevelTable.BOMHeaderQuantity,
			|	LevelTable.BOMQuantity,
			|	LevelTable.BOMCalculationMethod";
		
		QueryTextFragment2 = QueryTextFragment2 + StrTemplate(Text2, "LevelTable" + String(i), String(i));
		
	EndDo;
	
	Query.Text = Query.Text + QueryTextFragment1 + QueryTextFragment2 + DriveClientServer.GetQueryDelimeter() + "
		|SELECT
		|	AllLevelTable.Products AS Products,
		|	AllLevelTable.Characteristic AS Characteristic,
		|	AllLevelTable.ActivityNumber AS ActivityNumber,
		|	AllLevelTable.ConnectionKey AS ConnectionKey,
		|	AllLevelTable.Activity AS Activity,
		|	AllLevelTable.ParentActivity AS ParentActivity,
		|	AllLevelTable.ParentActivityNumber AS ParentActivityNumber,
		|	AllLevelTable.ParentConnectionKey AS ParentConnectionKey,
		|	CreatedWIP.WIP AS WIP,
		|	CreatedWIP.Output AS OutputWIP,
		|	AllLevelTable.Specification AS Specification,
		|	AllLevelTable.ActivitySpecification AS ActivitySpecification,
		|	AllLevelTable.SemifinishedProducts AS SemifinishedProducts,
		|	AllLevelTable.SemifinishedCharacteristic AS SemifinishedCharacteristic,
		|	AllLevelTable.HierarchyItem AS HierarchyItem,
		|	AllLevelTable.BOMHeaderQuantity AS BOMHeaderQuantity,
		|	AllLevelTable.BOMQuantity AS BOMQuantity,
		|	AllLevelTable.BOMCalculationMethod AS BOMCalculationMethod,
		|	AllLevelTable.Level AS Level,
		|	CASE
		|		WHEN ContentProducts.ReplenishmentMethod = VALUE(Enum.InventoryReplenishmentMethods.Processing)
		|			THEN VALUE(Enum.ProductionMethods.Subcontracting)
		|		ELSE VALUE(Enum.ProductionMethods.InHouseProduction)
		|	END AS ProductionMethod
		|FROM
		|	AllLevelTable AS AllLevelTable
		|		LEFT JOIN CreatedWIP AS CreatedWIP
		|		ON AllLevelTable.ConnectionKey = CreatedWIP.ConnectionKey
		|			AND AllLevelTable.ActivitySpecification = CreatedWIP.Specification
		|			AND AllLevelTable.HierarchyItem = CreatedWIP.HierarchyItem
		|		LEFT JOIN Catalog.Products AS ContentProducts
		|		ON AllLevelTable.SemifinishedProducts = ContentProducts.Ref
		|ORDER BY
		|	AllLevelTable.Products,
		|	AllLevelTable.Characteristic,
		|	AllLevelTable.ParentActivityNumber,
		|	AllLevelTable.ParentActivity,
		|	AllLevelTable.ActivityNumber,
		|	AllLevelTable.Activity,
		|	AllLevelTable.SemifinishedProducts,
		|	AllLevelTable.SemifinishedCharacteristic
		|AUTOORDER";
	
	Query.SetParameter("ProductionOrder", ProductionOrder);
	
	If IsOperationsShown Then
		Query.SetParameter("IsOutputWIP", True);
	Else
		Query.Text = StrReplace(Query.Text, "&IsOutputWIP", "ManufacturingOperationActivities.Output = True");
	EndIf;
	
	Result = Query.Execute().Unload();
	
	Return Result;
	
EndFunction

&AtServerNoContext
Function AvailableBalanceTable(Company, SemifinishedProducts)
	
	SemifinishedProducts = CommonClientServer.CollapseArray(SemifinishedProducts);
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	InventoryInWarehousesBalance.Company AS Company,
	|	InventoryInWarehousesBalance.Products AS Products,
	|	InventoryInWarehousesBalance.Characteristic AS Characteristic,
	|	InventoryInWarehousesBalance.Batch AS Batch,
	|	InventoryInWarehousesBalance.StructuralUnit AS StructuralUnit,
	|	InventoryInWarehousesBalance.QuantityBalance AS QuantityBalance
	|INTO TT_Balances
	|FROM
	|	AccumulationRegister.InventoryInWarehouses.Balance(
	|			,
	|			Company = &Company
	|				AND Products IN (&Products)) AS InventoryInWarehousesBalance
	|
	|UNION ALL
	|
	|SELECT
	|	ReservedProductsBalance.Company,
	|	ReservedProductsBalance.Products,
	|	ReservedProductsBalance.Characteristic,
	|	ReservedProductsBalance.Batch,
	|	ReservedProductsBalance.StructuralUnit,
	|	-ReservedProductsBalance.QuantityBalance
	|FROM
	|	AccumulationRegister.ReservedProducts.Balance(
	|			,
	|			Company = &Company
	|				AND Products IN (&Products)) AS ReservedProductsBalance
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_Balances.Company AS Company,
	|	TT_Balances.Products AS Products,
	|	TT_Balances.Characteristic AS Characteristic,
	|	TT_Balances.Batch AS Batch,
	|	TT_Balances.StructuralUnit AS StructuralUnit,
	|	SUM(TT_Balances.QuantityBalance) AS QuantityBalance
	|FROM
	|	TT_Balances AS TT_Balances
	|
	|GROUP BY
	|	TT_Balances.Company,
	|	TT_Balances.Characteristic,
	|	TT_Balances.Batch,
	|	TT_Balances.Products,
	|	TT_Balances.StructuralUnit";
	
	Query.SetParameter("Company", Company);
	Query.SetParameter("Products", SemifinishedProducts);
	
	Return Query.Execute().Unload();
	
EndFunction

&AtServerNoContext
Function GetProductionMethods(ArrayWIP)

	Query = New Query;
	Query.Text = 
	"SELECT
	|	ManufacturingOperation.Ref AS WIP,
	|	ManufacturingOperation.ProductionMethod AS ProductionMethod
	|FROM
	|	Document.ManufacturingOperation AS ManufacturingOperation
	|WHERE
	|	ManufacturingOperation.Ref IN(&ArrayWIP)";
	
	Query.SetParameter("ArrayWIP", ArrayWIP);
	
	Table = Query.Execute().Unload();
	Table.Indexes.Add("WIP");
	
	Return Table;

EndFunction

&AtClient
Procedure CollapseRecursively(TreeItems)
	
	For Each TreeItems_Item In TreeItems Do
		
		InTreeItems = TreeItems_Item.GetItems();
		If InTreeItems.Count() > 0 Then
			CollapseRecursively(InTreeItems);
		EndIf;
		Items.Operations.Collapse(TreeItems_Item.GetID());
		
	EndDo;
	
EndProcedure

&AtClient
Procedure SetCreateValueForAllItems(CreateValue)
	
	SetCreateValueItem(Operations.GetItems(), CreateValue);
	
EndProcedure

&AtClient
Procedure SetCreateValueItem(LevelProducts, CreateValue)
	
	For Each Level_Product In LevelProducts Do
		
		If Level_Product.WIP.IsEmpty() Then
			If Not ConsiderAvailableBalance Or Level_Product.QuantityToProduce > 0 Then
				Level_Product.Create = CreateValue;
				Modified = True;
			EndIf;
		EndIf;
		
		Level = Level_Product.GetItems();
		
		For Each Level_Item In Level Do
			
			If Not IsOperationsShown Then
				If Level_Item.WIP.IsEmpty() Then
					If Not ConsiderAvailableBalance Or Level_Item.QuantityToProduce > 0 Then
						Level_Item.Create = CreateValue;
						Modified = True;
					EndIf;
				EndIf;
			EndIf;
			
			SetCreateValueItem(Level_Item.GetItems(), CreateValue);
			
		EndDo;
		
	EndDo;
	
EndProcedure

// Procedure set conditional appearance
//
&AtServer
Procedure SetConditionalAppearance()
	
	NewConditionalAppearance = ConditionalAppearance.Items.Add();
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"Operations.Activity",
		Catalogs.ManufacturingActivities.EmptyRef(),
		DataCompositionComparisonType.NotEqual);
	
	WorkWithForm.AddAppearanceField(NewConditionalAppearance, "OperationsCreate");
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "ReadOnly", True);
	
	NewConditionalAppearance = ConditionalAppearance.Items.Add();
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"Operations.Activity",
		Catalogs.ManufacturingActivities.EmptyRef(),
		DataCompositionComparisonType.NotEqual);
	
	WorkWithForm.AddAppearanceField(NewConditionalAppearance, "OperationsSemifinishedCharacteristic, OperationsSemifinishedProducts");
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "Visible", False);
	
	NewConditionalAppearance = ConditionalAppearance.Items.Add();
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"Operations.WIP",
		Documents.ManufacturingOperation.EmptyRef(),
		DataCompositionComparisonType.NotEqual);
	
	WorkWithForm.AddAppearanceField(NewConditionalAppearance, "OperationsCreate");
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "ReadOnly", True);
	
	NewConditionalAppearance = ConditionalAppearance.Items.Add();
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"Operations.Activity",
		Catalogs.ManufacturingActivities.EmptyRef());
		
	WorkWithForm.AddAppearanceField(NewConditionalAppearance, "GroupOperation");
	WorkWithForm.AddAppearanceField(NewConditionalAppearance, "OperationsActivityNumber");
	WorkWithForm.AddAppearanceField(NewConditionalAppearance, "OperationsActivity");
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "Visible", False);
	
	NewConditionalAppearance = ConditionalAppearance.Items.Add();
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"Operations.Activity",
		Catalogs.ManufacturingActivities.EmptyRef(),
		DataCompositionComparisonType.NotEqual);
	
	WorkWithForm.AddAppearanceField(NewConditionalAppearance, "GroupOperation");
	WorkWithForm.AddAppearanceField(NewConditionalAppearance, "OperationsActivityNumber");
	WorkWithForm.AddAppearanceField(NewConditionalAppearance, "OperationsActivity");
	WorkWithForm.AddAppearanceField(NewConditionalAppearance, "OperationsQuantityByBOM");
	WorkWithForm.AddAppearanceField(NewConditionalAppearance, "OperationsQuantityAvailable");
	WorkWithForm.AddAppearanceField(NewConditionalAppearance, "OperationsQuantityToProduce");
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "TextColor", StyleColors.EmptyHyperlinkColor);
	
	NewConditionalAppearance = ConditionalAppearance.Items.Add();
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"Operations.Activity",
		Catalogs.ManufacturingActivities.EmptyRef(),
		DataCompositionComparisonType.NotEqual);
		
	WorkWithForm.AddAppearanceField(NewConditionalAppearance, "OperationsQuantityByBOM");
	WorkWithForm.AddAppearanceField(NewConditionalAppearance, "OperationsQuantityAvailable");
	WorkWithForm.AddAppearanceField(NewConditionalAppearance, "OperationsQuantityToProduce");
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "ReadOnly", True);
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "Text", "");
	
	NewConditionalAppearance = ConditionalAppearance.Items.Add();
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"Operations.WIP",
		Documents.ManufacturingOperation.EmptyRef(),
		DataCompositionComparisonType.NotEqual);
		
	WorkWithForm.AddAppearanceField(NewConditionalAppearance, "OperationsQuantityByBOM");
	WorkWithForm.AddAppearanceField(NewConditionalAppearance, "OperationsQuantityAvailable");
	WorkWithForm.AddAppearanceField(NewConditionalAppearance, "OperationsQuantityToProduce");
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "ReadOnly", True);
	
	NewConditionalAppearance = ConditionalAppearance.Items.Add();
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"Operations.Level",
		0);
		
	WorkWithForm.AddAppearanceField(NewConditionalAppearance, "OperationsQuantityByBOM");
	WorkWithForm.AddAppearanceField(NewConditionalAppearance, "OperationsQuantityAvailable");
	WorkWithForm.AddAppearanceField(NewConditionalAppearance, "OperationsQuantityToProduce");
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "ReadOnly", True);
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "TextColor", StyleColors.EmptyHyperlinkColor);
	
	NewConditionalAppearance = ConditionalAppearance.Items.Add();
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"Operations.Level",
		0);
		
	WorkWithForm.AddAppearanceField(NewConditionalAppearance, "OperationsQuantityByBOM");
	WorkWithForm.AddAppearanceField(NewConditionalAppearance, "OperationsQuantityAvailable");
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "Text", "");
	
	If GetFunctionalOption("CanReceiveSubcontractingServices") Then
		
		NewConditionalAppearance = ConditionalAppearance.Items.Add();
		WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
			"Operations.Level",
			0);
			
		WorkWithForm.AddAppearanceField(NewConditionalAppearance, "OperationsProductionMethod"); 
		WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "ReadOnly", True);
		
		NewConditionalAppearance = ConditionalAppearance.Items.Add();
		WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
			"Operations.Activity",
			Catalogs.ManufacturingActivities.EmptyRef(),
			DataCompositionComparisonType.NotEqual);
		
		WorkWithForm.AddAppearanceField(NewConditionalAppearance, "OperationsProductionMethod");
		WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "ReadOnly", True);

	Else
		Items.OperationsProductionMethod.Visible = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure SetFlagForAllHigherRankingLines(TreeLine)
	
	TreeLineParent = TreeLine.GetParent();
	If TreeLineParent <> Undefined Then
		If Not ValueIsFilled(TreeLineParent.WIP) Then
			TreeLineParent.Create = True;
			SetFlagForAllHigherRankingLines(TreeLineParent);
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure ClearFlagForAllLowerRankingLines(TreeLine)
	
	TreeLineItems = TreeLine.GetItems();
	For Each TreeLineItem In TreeLineItems Do
		If Not ValueIsFilled(TreeLineItem.WIP) Then
			TreeLineItem.Create = False;
			ClearFlagForAllLowerRankingLines(TreeLineItem);
		EndIf;
	EndDo;
	
EndProcedure

&AtServer
Function AllWIPsAreAllowed()
	
	Result = True;
	
	Try
		
		Query = New Query;
		Query.Text = 
		"SELECT
		|	ManufacturingOperation.Ref AS Ref
		|FROM
		|	Document.ManufacturingOperation AS ManufacturingOperation
		|WHERE
		|	ManufacturingOperation.BasisDocument = &ProductionOrder
		|	AND ManufacturingOperation.Posted";
		
		Query.SetParameter("ProductionOrder", ProductionOrder);
		Query.Execute();
		
	Except
		
		Result = False;
		
	EndTry;
	
	Return Result;
	
EndFunction

#EndRegion
