#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	FillParameters(Parameters.FillingValues);
	DefaultGLAccounts = GetDefaultGLAccounts();
	FormManagment();
	
	If Not ValueIsFilled(Parameters.Key.Company)
		And Not ValueIsFilled(Parameters.Key.Product)
		And Not ValueIsFilled(Parameters.Key.ProductCategory)
		And Not ValueIsFilled(Parameters.Key.StructuralUnit) Then
		
		IsDefaultRecord = FormAttributeToValue("Record").Selected();
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	If Modified
		And Not WriteParameters.Property("DontAskNeedToFillEmptyAccounts")
		And NeedToFillEmptyAccounts() Then
		
		Text = NStr("en = 'You have not filled in some of the GL accounts.
			|They will be populated from the generic GL account settings applicable to all counterparties.'; 
			|ru = 'Вы не указали некоторые счета учета.
			|Они будут заполнены из общих настроек счетов учета, применяемых ко всем контрагентам.';
			|pl = 'Nie wypełniono kilku kont księgowych.
			|Zostaną one wypełnione na podstawie ogólnych ustawień kont księgowych, które mają zastosowanie dla wszystkich kontrahentów.';
			|es_ES = 'No ha completado algunas de las cuentas del libro mayor.
			|Se completarán a partir de la configuración de la cuenta del libro mayor genérica aplicable a todas las contrapartes.';
			|es_CO = 'No ha completado algunas de las cuentas del libro mayor.
			|Se completarán a partir de la configuración de la cuenta del libro mayor genérica aplicable a todas las contrapartes.';
			|tr = 'Muhasebe hesaplarından bazılarını doldurmadınız.
			|Tüm cari hesaplara uygulanabilecek jenerik muhasebe hesabı ayarlarından doldurulacaklar.';
			|it = 'Non sono stati compilati alcuni conti mastro.
			| Saranno compilati dalle impostazioni generiche di conto mastro applicabili a tutte le controparti.';
			|de = 'Sie haben einige der Hauptbuch-Konten nicht aufgefüllt.
			|Sie werden aus für alle Geschäftspartner verwendbaren Ober-Einstellungen des Hauptbuch-Kontos automatisch aufgefüllt.'");
		Notification = New NotifyDescription("FillCheckEnd", ThisObject, WriteParameters);
		ShowQueryBox(Notification, Text, QuestionDialogMode.YesNo, , DialogReturnCode.Yes);
		
		Cancel = True;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure ProductOnChange(Item)
	ProductOnChangeAtServer();
EndProcedure

&AtClient
Procedure ProductCategoryChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	DimensionsChoiceProcessing(Nstr("en='Product category'; ru = 'Категория номенклатуры';pl = 'Kategoria produktu';es_ES = 'Categoría de producto';es_CO = 'Categoría de producto';tr = 'Ürün kategorisi';it = 'Categoria articolo';de = 'Produktkategorie'"), StandardProcessing);
	
EndProcedure

&AtClient
Procedure CompanyChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	DimensionsChoiceProcessing(Nstr("en='Company'; ru = 'Организация';pl = 'Firma';es_ES = 'Empresa';es_CO = 'Empresa';tr = 'İş yeri';it = 'Azienda';de = 'Firma'"), StandardProcessing);
	
EndProcedure

&AtClient
Procedure ProductChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	DimensionsChoiceProcessing(Nstr("en='Product'; ru = 'Номенклатура';pl = 'Produkt';es_ES = 'Producto';es_CO = 'Producto';tr = 'Ürün';it = 'Articolo';de = 'Produkt'"), StandardProcessing);
	
EndProcedure

&AtClient
Procedure StructuralUnitChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	DimensionsChoiceProcessing(Nstr("en='Warehouse'; ru = 'Склад';pl = 'Magazyn';es_ES = 'Almacén';es_CO = 'Almacén';tr = 'Ambar';it = 'Magazzino';de = 'Lager'"), StandardProcessing);
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure FillParameters(FillingValues)
	
	For Each Parameter In FillingValues Do
		
		If TypeOf(Parameter.Value) <> Type("ValueList") Then
			Continue;
		EndIf;
		
		Array = Parameter.Value[0].Value;
		
		For Each Item In Array Do
			If ValueIsFilled(Item) Then
				Record[Parameter.Key] = Item;
				Break;
			EndIf;
		EndDo;
	EndDo;
	
EndProcedure

&AtServer
Procedure FormManagment()

	ProductType = Common.ObjectAttributeValue(Record.Product, "ProductsType");
	IsEmptyProductType = Not ValueIsFilled(ProductType);
	
	IsInventoryItem = (ProductType = Enums.ProductsTypes.InventoryItem)
		Or IsEmptyProductType;
	
	Items.StructuralUnit.Visible		= IsInventoryItem;
	
	Items.GroupInStock.Visible			= IsInventoryItem;
	Items.GroupDelayedInvoicing.Visible	= IsInventoryItem;
	Items.GroupReturn.Visible			= IsInventoryItem;
	Items.GroupDelayedDelivery.Visible	= IsInventoryItem;
	
	Items.COGS.Visible					= IsInventoryItem;
	Items.Consumption.Visible			= IsInventoryItem;
	Items.AbnormalScrap.Visible			= IsInventoryItem;
	Items.ProductType.Visible			= Not IsEmptyProductType;
	
EndProcedure

&AtServer
Procedure ProductOnChangeAtServer()
	FormManagment();
EndProcedure

&AtClient
Procedure FillCheckEnd(QuestionResult, AdditionalParameters) Export
	
	If QuestionResult = DialogReturnCode.Yes Then
		FillEmptyGLAccounts();
	EndIf;
	
	If IsGenericGLAccountSettings() 
		And NeedToFillEmptyAccounts() Then
		
		CommonClientServer.MessageToUser(NStr("en = 'You have not filled in some of the GL accounts.'; ru = 'Вы не указали некоторые счета учета.';pl = 'Nie wypełniono kilku kont księgowych.';es_ES = 'No ha completado algunas de las cuentas del libro mayor.';es_CO = 'No ha completado algunas de las cuentas del libro mayor.';tr = 'Muhasebe hesaplarından bazılarını doldurmadınız.';it = 'Non sono stati compilati alcuni conti mastro.';de = 'Sie haben einige der Hauptbuch-Konten nicht aufgefüllt.'"));
	Else	
		Write(New Structure("DontAskNeedToFillEmptyAccounts"));
	EndIf;	
	
EndProcedure

&AtClient
Procedure FillEmptyGLAccounts()
	
	For Each GLAccount In ProductTypeDefaultGLAccounts Do
		
		AttributeName = Left(GLAccount.Key, StrLen(GLAccount.Key) - 9);
		
		If Not ValueIsFilled(Record[AttributeName]) Then
			Record[AttributeName] = ProductTypeDefaultGLAccounts[GLAccount.Key];
		EndIf;
		
	EndDo;
	
EndProcedure

&AtServerNoContext
Function GetDefaultGLAccounts()

	EmptyProduct = Catalogs.Products.EmptyRef();
	StructureData = New Structure("ObjectParameters, Products", New Structure, EmptyProduct);
	GLAccounts = GLAccountsInDocuments.GetProductListGLAccounts(StructureData);
	DefaultGLAccounts = GLAccounts[EmptyProduct];
	DefaultGLAccounts.Delete("GoodsInTransitGLAccount");
	DefaultGLAccounts.Delete("InventoryToGLAccount");
	
	Return DefaultGLAccounts;

EndFunction

&AtClient
Function NeedToFillEmptyAccounts()

	ProductTypeDefaultGLAccounts = GetProductTypeDefaultGLAccounts();
	
	For Each Account In ProductTypeDefaultGLAccounts Do
		
		AttributeName = Left(Account.Key, StrLen(Account.Key) - 9);
		
		If Not ValueIsFilled(Record[AttributeName])
			And ValueIsFilled(Account.Value) Then
			Return True;
			Break;
		EndIf;
			
	EndDo;
	
	Return False;

EndFunction

&AtClient
Function GetProductTypeDefaultGLAccounts()
	
	If Not IsInventoryItem Then
		ProductTypeGLAccounts = New Structure("InventoryGLAccount, RevenueGLAccount, VATInputGLAccount, VATOutputGLAccount");
		FillPropertyValues(ProductTypeGLAccounts, DefaultGLAccounts);
	Else
		ProductTypeGLAccounts = DefaultGLAccounts;
	EndIf;
	
	Return ProductTypeGLAccounts;
	
EndFunction

&AtClient
Function IsGenericGLAccountSettings()
	
	Result = False;
	
	If Not ValueIsFilled(Record.Company)
		And Not ValueIsFilled(Record.StructuralUnit)
		And Not ValueIsFilled(Record.Product)
		And Not ValueIsFilled(Record.ProductCategory) Then
		
		Result = True;
	EndIf;
	
	Return Result;
	
EndFunction

&AtClient
Procedure DimensionsChoiceProcessing(DimensionName, StandardProcessing)
	
	If IsDefaultRecord Then
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Cannot change %1.
					|This window includes generic GL account settings applicable to all products.
					|The settings are nonspecific to a certain %1. It must be blank.'; 
					|ru = 'Не удалось изменить %1.
					|Это окно включает в себя общие настройки счетов учета, применимые ко всей номенклатуре.
					|Настройки не зависят от определенного %1. Он должен быть пустым.';
					|pl = 'Nie można zmienić %1.
					|To okno zawiera ogólne ustawienia konta księgowego, mające zastosowanie dla wszystkich produktów.
					|Ustawienia nie są specyficzne dla określonego %1. Powinno ono być puste.';
					|es_ES = 'No se puede cambiar %1.
					|Esta ventana incluye la configuración de la cuenta del libro mayor genérica aplicable a todos los productos.
					|La configuración no es específica para un %1 determinado. Debe estar en blanco.';
					|es_CO = 'No se puede cambiar %1.
					|Esta ventana incluye la configuración de la cuenta del libro mayor genérica aplicable a todos los productos.
					|La configuración no es específica para un %1 determinado. Debe estar en blanco.';
					|tr = '%1 değiştirilemiyor.
					|Bu pencere, tüm ürünlere uygulanabilecek jenerik muhasebe hesabı ayarları içeriyor.
					|Ayarlar %1 öğesine özel değil. Boş olmalı.';
					|it = 'Impossibile modificare %1.
					|Questa finestra include le impostazioni generali dei conti mastro applicabili a tutti gli articoli.
					|Le impostazioni non sono specifiche per determinati %1. Deve essere vuoto.';
					|de = 'Fehler beim Ändern von %1.
					|Dieses Fenster enthält für alle Produkte verwendbare Ober-Einstellungen des Hauptbuch-Kontos.
					|Die Einstellungen sind für bestimmte %1 nicht spezifisch. Es muss leer sein.'"), DimensionName);
		CommonClientServer.MessageToUser(MessageText);
		
		StandardProcessing = False;
	EndIf;
	
EndProcedure

#EndRegion
