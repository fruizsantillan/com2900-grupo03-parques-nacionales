# =============================================
# Universidad Nacional de La Matanza
# Materia: 3641 - Bases de Datos Aplicada
# Grupo: 03
# Integrantes: Ruiz Santillan, Facundo - Lago, Franco Nehuen
#              Del Vecchio, Fabrizio - Ocampos, Horacio.
# Fecha: 27/06/2026
# Descripcion: Entrega 9 - Aplicacion de escritorio para el ABM de Ventas.
#   Permite gestionar tickets de venta y sus lineas (entradas, tours,
#   atracciones) usando los Stored Procedures de la base ParquesNacionales.
#   Conexion: Autenticacion de Windows (Trusted_Connection).
#   GUI: Tkinter (incluido en Python). Driver: pyodbc.
#
# Requisitos:
#   pip install pyodbc
#   ODBC Driver 17 (o 18) for SQL Server instalado.
#
# SPs usados:
#   ventas.TicketVenta_Insertar / _Actualizar / _Eliminar
#   ventas.LineaVenta_Insertar  / _Actualizar / _Eliminar
#   ventas.RegistrarVentaEntrada (negocio)
# =============================================

import tkinter as tk
from tkinter import ttk, messagebox
import pyodbc

# -------------------------------------------------
# CONFIGURACION DE CONEXION
# Ajustar SERVER al nombre de la instancia local.
# Ejemplos comunes: 'localhost', '.\\SQLEXPRESS', '(local)'
# -------------------------------------------------
SERVER   = 'localhost'
DATABASE = 'ParquesNacionales'
# Se intentan varios drivers por compatibilidad
DRIVERS  = [
    'ODBC Driver 18 for SQL Server',
    'ODBC Driver 17 for SQL Server',
    'SQL Server',
]


def get_connection():
    """Abre una conexion a SQL Server con autenticacion de Windows."""
    ultimo_error = None
    for driver in DRIVERS:
        try:
            conn = pyodbc.connect(
                f'DRIVER={{{driver}}};'
                f'SERVER={SERVER};'
                f'DATABASE={DATABASE};'
                f'Trusted_Connection=yes;'
                f'TrustServerCertificate=yes;',
                autocommit=True
            )
            return conn
        except pyodbc.Error as e:
            ultimo_error = e
            continue
    raise ultimo_error


class AppVentas(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title('ABM de Ventas - Parques Nacionales (Grupo 03)')
        self.geometry('1000x650')
        self.conn = None

        # Caches para los combos (descripcion -> id)
        self.parques = {}
        self.tipos_visitante = {}
        self.precios = {}   # (idParque, idTipoVisitante) -> idPrecio
        self.tours = {}
        self.atracciones = {}

        self._conectar()
        self._construir_ui()
        self._cargar_combos()
        self._refrescar_tickets()

    # =========================================================
    # CONEXION
    # =========================================================
    def _conectar(self):
        try:
            self.conn = get_connection()
        except Exception as e:
            messagebox.showerror(
                'Error de conexion',
                f'No se pudo conectar a SQL Server.\n\n'
                f'Servidor: {SERVER}\nBase: {DATABASE}\n\n'
                f'Detalle: {e}\n\n'
                f'Revise el nombre del servidor en la constante SERVER '
                f'y que el ODBC Driver este instalado.'
            )
            self.destroy()
            raise SystemExit

    def ejecutar_sp(self, sql, params=()):
        """Ejecuta un SP que no devuelve filas. Devuelve (ok, mensaje)."""
        try:
            cur = self.conn.cursor()
            cur.execute(sql, params)
            # Capturar PRINTs / mensajes del SP si los hubiera
            cur.close()
            return True, 'Operacion realizada correctamente.'
        except pyodbc.Error as e:
            # El mensaje del RAISERROR del SP viene en el args
            msg = e.args[1] if len(e.args) > 1 else str(e)
            return False, msg

    def consultar(self, sql, params=()):
        """Ejecuta una consulta y devuelve filas + nombres de columna."""
        cur = self.conn.cursor()
        cur.execute(sql, params)
        cols = [c[0] for c in cur.description] if cur.description else []
        filas = cur.fetchall() if cur.description else []
        cur.close()
        return cols, filas

    # =========================================================
    # UI
    # =========================================================
    def _construir_ui(self):
        nb = ttk.Notebook(self)
        nb.pack(fill='both', expand=True, padx=8, pady=8)

        self.tab_tickets = ttk.Frame(nb)
        self.tab_lineas  = ttk.Frame(nb)
        nb.add(self.tab_tickets, text='Tickets de Venta')
        nb.add(self.tab_lineas,  text='Lineas de Venta')

        self._construir_tab_tickets()
        self._construir_tab_lineas()

    # ---------- TAB TICKETS ----------
    def _construir_tab_tickets(self):
        frm = self.tab_tickets

        # --- Formulario ---
        cont = ttk.LabelFrame(frm, text='Datos del Ticket')
        cont.pack(fill='x', padx=8, pady=6)

        ttk.Label(cont, text='Parque:').grid(row=0, column=0, sticky='e', padx=4, pady=4)
        self.cb_parque_tk = ttk.Combobox(cont, state='readonly', width=35)
        self.cb_parque_tk.grid(row=0, column=1, padx=4, pady=4)

        ttk.Label(cont, text='Punto de venta:').grid(row=0, column=2, sticky='e', padx=4, pady=4)
        self.e_punto = ttk.Entry(cont, width=12)
        self.e_punto.grid(row=0, column=3, padx=4, pady=4)

        ttk.Label(cont, text='Forma de pago:').grid(row=1, column=0, sticky='e', padx=4, pady=4)
        self.cb_pago = ttk.Combobox(cont, state='readonly', width=33,
                                    values=['Efectivo', 'Tarjeta de debito',
                                            'Tarjeta de credito', 'Transferencia', 'QR'])
        self.cb_pago.grid(row=1, column=1, padx=4, pady=4)
        self.cb_pago.set('Efectivo')

        # --- Botones ---
        btns = ttk.Frame(frm)
        btns.pack(fill='x', padx=8, pady=4)
        ttk.Button(btns, text='Crear ticket',     command=self._crear_ticket).pack(side='left', padx=3)
        ttk.Button(btns, text='Actualizar pago',  command=self._actualizar_ticket).pack(side='left', padx=3)
        ttk.Button(btns, text='Eliminar ticket',  command=self._eliminar_ticket).pack(side='left', padx=3)
        ttk.Button(btns, text='Refrescar',        command=self._refrescar_tickets).pack(side='left', padx=3)

        # --- Grilla ---
        cols = ('idTicket', 'fechaHora', 'parque', 'puntoDeVenta', 'nroTicket', 'formaPago', 'total')
        self.tree_tk = ttk.Treeview(frm, columns=cols, show='headings', height=15)
        encabezados = {
            'idTicket': 'ID', 'fechaHora': 'Fecha/Hora', 'parque': 'Parque',
            'puntoDeVenta': 'Pto.Venta', 'nroTicket': 'Nro', 'formaPago': 'Forma Pago',
            'total': 'Total'
        }
        anchos = {'idTicket': 50, 'fechaHora': 140, 'parque': 220, 'puntoDeVenta': 80,
                  'nroTicket': 60, 'formaPago': 130, 'total': 100}
        for c in cols:
            self.tree_tk.heading(c, text=encabezados[c])
            self.tree_tk.column(c, width=anchos[c], anchor='center')
        self.tree_tk.pack(fill='both', expand=True, padx=8, pady=6)
        self.tree_tk.bind('<<TreeviewSelect>>', self._on_select_ticket)

    # ---------- TAB LINEAS ----------
    def _construir_tab_lineas(self):
        frm = self.tab_lineas

        # Seleccion de ticket
        top = ttk.LabelFrame(frm, text='Ticket')
        top.pack(fill='x', padx=8, pady=6)
        ttk.Label(top, text='Ticket ID:').grid(row=0, column=0, sticky='e', padx=4, pady=4)
        self.cb_ticket_ln = ttk.Combobox(top, state='readonly', width=30)
        self.cb_ticket_ln.grid(row=0, column=1, padx=4, pady=4)
        self.cb_ticket_ln.bind('<<ComboboxSelected>>', lambda e: self._refrescar_lineas())
        ttk.Button(top, text='Recargar tickets', command=self._cargar_combo_tickets).grid(row=0, column=2, padx=6)

        # Formulario de linea
        cont = ttk.LabelFrame(frm, text='Datos de la Linea')
        cont.pack(fill='x', padx=8, pady=6)

        ttk.Label(cont, text='Tipo de item:').grid(row=0, column=0, sticky='e', padx=4, pady=4)
        self.cb_tipo_item = ttk.Combobox(cont, state='readonly', width=20,
                                         values=['Entrada', 'Tour', 'Atraccion'])
        self.cb_tipo_item.grid(row=0, column=1, padx=4, pady=4)
        self.cb_tipo_item.set('Entrada')
        self.cb_tipo_item.bind('<<ComboboxSelected>>', lambda e: self._actualizar_combo_item())

        ttk.Label(cont, text='Item:').grid(row=0, column=2, sticky='e', padx=4, pady=4)
        self.cb_item = ttk.Combobox(cont, state='readonly', width=40)
        self.cb_item.grid(row=0, column=3, padx=4, pady=4)

        ttk.Label(cont, text='Tipo visitante:').grid(row=1, column=0, sticky='e', padx=4, pady=4)
        self.cb_tipo_vis = ttk.Combobox(cont, state='readonly', width=20)
        self.cb_tipo_vis.grid(row=1, column=1, padx=4, pady=4)

        ttk.Label(cont, text='Cantidad:').grid(row=1, column=2, sticky='e', padx=4, pady=4)
        self.e_cantidad = ttk.Entry(cont, width=12)
        self.e_cantidad.grid(row=1, column=3, sticky='w', padx=4, pady=4)
        self.e_cantidad.insert(0, '1')

        # Botones lineas
        btns = ttk.Frame(frm)
        btns.pack(fill='x', padx=8, pady=4)
        ttk.Button(btns, text='Agregar linea',    command=self._agregar_linea).pack(side='left', padx=3)
        ttk.Button(btns, text='Actualizar linea', command=self._actualizar_linea).pack(side='left', padx=3)
        ttk.Button(btns, text='Eliminar linea',   command=self._eliminar_linea).pack(side='left', padx=3)
        ttk.Button(btns, text='Refrescar',        command=self._refrescar_lineas).pack(side='left', padx=3)

        # Grilla lineas
        cols = ('idLineaVenta', 'descripcion', 'cantidad', 'precioUnitario', 'subtotal')
        self.tree_ln = ttk.Treeview(frm, columns=cols, show='headings', height=13)
        enc = {'idLineaVenta': 'ID', 'descripcion': 'Descripcion', 'cantidad': 'Cant.',
               'precioUnitario': 'P.Unit.', 'subtotal': 'Subtotal'}
        anchos = {'idLineaVenta': 60, 'descripcion': 380, 'cantidad': 80,
                  'precioUnitario': 120, 'subtotal': 120}
        for c in cols:
            self.tree_ln.heading(c, text=enc[c])
            self.tree_ln.column(c, width=anchos[c], anchor='center')
        self.tree_ln.pack(fill='both', expand=True, padx=8, pady=6)
        self.tree_ln.bind('<<TreeviewSelect>>', self._on_select_linea)

        self._actualizar_combo_item()

    # =========================================================
    # CARGA DE COMBOS
    # =========================================================
    def _cargar_combos(self):
        # Parques
        cols, filas = self.consultar(
            'SELECT idParque, nombre FROM parques.Parque ORDER BY nombre')
        self.parques = {f.nombre: f.idParque for f in filas}
        valores = list(self.parques.keys())
        self.cb_parque_tk['values'] = valores
        if valores:
            self.cb_parque_tk.set(valores[0])

        # Tipos de visitante
        cols, filas = self.consultar(
            'SELECT idTipoVisitante, descripcion FROM ventas.TipoVisitante ORDER BY descripcion')
        self.tipos_visitante = {f.descripcion: f.idTipoVisitante for f in filas}
        self.cb_tipo_vis['values'] = list(self.tipos_visitante.keys())
        if self.tipos_visitante:
            self.cb_tipo_vis.set(list(self.tipos_visitante.keys())[0])

        # Tours
        cols, filas = self.consultar(
            'SELECT idTour, nombre, precio FROM actividades.Tour ORDER BY nombre')
        self.tours = {f'{f.nombre} (${f.precio})': f.idTour for f in filas}

        # Atracciones
        cols, filas = self.consultar(
            'SELECT idAtraccion, nombre, precio FROM actividades.Atraccion ORDER BY nombre')
        self.atracciones = {f'{f.nombre} (${f.precio})': f.idAtraccion for f in filas}

        self._cargar_combo_tickets()
        self._actualizar_combo_item()

    def _cargar_combo_tickets(self):
        cols, filas = self.consultar(
            'SELECT idTicket, nroTicket, puntoDeVenta FROM ventas.TicketVenta '
            'ORDER BY idTicket DESC')
        self.tickets_combo = {
            f'Ticket {f.idTicket} (PV {f.puntoDeVenta}, Nro {f.nroTicket})': f.idTicket
            for f in filas
        }
        vals = list(self.tickets_combo.keys())
        self.cb_ticket_ln['values'] = vals
        if vals and not self.cb_ticket_ln.get():
            self.cb_ticket_ln.set(vals[0])

    def _actualizar_combo_item(self):
        tipo = self.cb_tipo_item.get()
        if tipo == 'Entrada':
            # Para entrada se usa tipo de visitante, el item se resuelve por precio vigente
            self.cb_item['values'] = ['(definido por parque + tipo visitante)']
            self.cb_item.set('(definido por parque + tipo visitante)')
            self.cb_item.configure(state='disabled')
            self.cb_tipo_vis.configure(state='readonly')
        elif tipo == 'Tour':
            self.cb_item.configure(state='readonly')
            self.cb_item['values'] = list(self.tours.keys())
            if self.tours:
                self.cb_item.set(list(self.tours.keys())[0])
            self.cb_tipo_vis.configure(state='disabled')
        else:  # Atraccion
            self.cb_item.configure(state='readonly')
            self.cb_item['values'] = list(self.atracciones.keys())
            if self.atracciones:
                self.cb_item.set(list(self.atracciones.keys())[0])
            self.cb_tipo_vis.configure(state='disabled')

    # =========================================================
    # ACCIONES TICKETS
    # =========================================================
    def _crear_ticket(self):
        parque = self.cb_parque_tk.get()
        punto  = self.e_punto.get().strip()
        pago   = self.cb_pago.get()

        if not parque:
            messagebox.showwarning('Validacion', 'Seleccione un parque.')
            return
        if not punto.isdigit():
            messagebox.showwarning('Validacion', 'El punto de venta debe ser un numero.')
            return

        ok, msg = self.ejecutar_sp(
            '{CALL ventas.TicketVenta_Insertar (?, ?, ?)}',
            (int(punto), pago, self.parques[parque])
        )
        if ok:
            messagebox.showinfo('Ticket', 'Ticket creado correctamente.')
            self._refrescar_tickets()
            self._cargar_combo_tickets()
        else:
            messagebox.showerror('Error', msg)

    def _actualizar_ticket(self):
        sel = self.tree_tk.selection()
        if not sel:
            messagebox.showwarning('Validacion', 'Seleccione un ticket de la grilla.')
            return
        id_ticket = self.tree_tk.item(sel[0])['values'][0]
        pago = self.cb_pago.get()

        ok, msg = self.ejecutar_sp(
            '{CALL ventas.TicketVenta_Actualizar (?, ?)}',
            (id_ticket, pago)
        )
        if ok:
            messagebox.showinfo('Ticket', 'Forma de pago actualizada.')
            self._refrescar_tickets()
        else:
            messagebox.showerror('Error', msg)

    def _eliminar_ticket(self):
        sel = self.tree_tk.selection()
        if not sel:
            messagebox.showwarning('Validacion', 'Seleccione un ticket de la grilla.')
            return
        id_ticket = self.tree_tk.item(sel[0])['values'][0]
        if not messagebox.askyesno('Confirmar',
                                   f'Eliminar el ticket {id_ticket} y todas sus lineas?'):
            return
        ok, msg = self.ejecutar_sp(
            '{CALL ventas.TicketVenta_Eliminar (?)}', (id_ticket,))
        if ok:
            messagebox.showinfo('Ticket', 'Ticket eliminado.')
            self._refrescar_tickets()
            self._cargar_combo_tickets()
        else:
            messagebox.showerror('Error', msg)

    def _refrescar_tickets(self):
        for i in self.tree_tk.get_children():
            self.tree_tk.delete(i)
        cols, filas = self.consultar('''
            SELECT t.idTicket, t.fechaHora, ISNULL(p.nombre, '-') AS parque,
                   t.puntoDeVenta, t.nroTicket, t.formaPago, t.total
            FROM ventas.TicketVenta t
            LEFT JOIN parques.Parque p ON p.idParque = t.idParque
            ORDER BY t.idTicket DESC
        ''')
        for f in filas:
            self.tree_tk.insert('', 'end', values=(
                f.idTicket,
                f.fechaHora.strftime('%d/%m/%Y %H:%M') if f.fechaHora else '',
                f.parque, f.puntoDeVenta, f.nroTicket, f.formaPago,
                f'{f.total:.2f}'
            ))

    def _on_select_ticket(self, _evt):
        sel = self.tree_tk.selection()
        if not sel:
            return
        vals = self.tree_tk.item(sel[0])['values']
        # vals: idTicket, fechaHora, parque, puntoDeVenta, nroTicket, formaPago, total
        self.cb_pago.set(vals[5])

    # =========================================================
    # ACCIONES LINEAS
    # =========================================================
    def _id_ticket_seleccionado(self):
        clave = self.cb_ticket_ln.get()
        return self.tickets_combo.get(clave)

    def _resolver_precio_entrada(self, id_parque, id_tipo_vis):
        """Devuelve idPrecio vigente para parque + tipo visitante, o None."""
        cols, filas = self.consultar('''
            SELECT idPrecio FROM ventas.PrecioEntrada
            WHERE idParque = ? AND idTipoVisitante = ? AND fechaHasta IS NULL
        ''', (id_parque, id_tipo_vis))
        return filas[0].idPrecio if filas else None

    def _id_parque_de_ticket(self, id_ticket):
        cols, filas = self.consultar(
            'SELECT idParque FROM ventas.TicketVenta WHERE idTicket = ?', (id_ticket,))
        return filas[0].idParque if filas else None

    def _agregar_linea(self):
        id_ticket = self._id_ticket_seleccionado()
        if not id_ticket:
            messagebox.showwarning('Validacion', 'Seleccione un ticket.')
            return
        cant = self.e_cantidad.get().strip()
        if not cant.isdigit() or int(cant) <= 0:
            messagebox.showwarning('Validacion', 'La cantidad debe ser un entero mayor a 0.')
            return
        cant = int(cant)
        tipo = self.cb_tipo_item.get()

        id_precio = id_tour = id_atraccion = None

        if tipo == 'Entrada':
            id_parque = self._id_parque_de_ticket(id_ticket)
            tv = self.cb_tipo_vis.get()
            if not tv:
                messagebox.showwarning('Validacion', 'Seleccione el tipo de visitante.')
                return
            id_precio = self._resolver_precio_entrada(id_parque, self.tipos_visitante[tv])
            if id_precio is None:
                messagebox.showerror(
                    'Sin precio',
                    'No existe un precio de entrada vigente para ese parque y '
                    'tipo de visitante. Cargue el precio primero.')
                return
        elif tipo == 'Tour':
            item = self.cb_item.get()
            id_tour = self.tours.get(item)
        else:
            item = self.cb_item.get()
            id_atraccion = self.atracciones.get(item)

        ok, msg = self.ejecutar_sp(
            '{CALL ventas.LineaVenta_Insertar (?, ?, ?, ?, ?)}',
            (id_ticket, cant, id_precio, id_tour, id_atraccion)
        )
        if ok:
            self._refrescar_lineas()
            self._refrescar_tickets()
        else:
            messagebox.showerror('Error', msg)

    def _actualizar_linea(self):
        sel = self.tree_ln.selection()
        if not sel:
            messagebox.showwarning('Validacion', 'Seleccione una linea de la grilla.')
            return
        id_linea = self.tree_ln.item(sel[0])['values'][0]
        cant = self.e_cantidad.get().strip()
        if not cant.isdigit() or int(cant) <= 0:
            messagebox.showwarning('Validacion', 'La cantidad debe ser un entero mayor a 0.')
            return
        cant = int(cant)
        tipo = self.cb_tipo_item.get()
        id_ticket = self._id_ticket_seleccionado()

        id_precio = id_tour = id_atraccion = None
        if tipo == 'Entrada':
            id_parque = self._id_parque_de_ticket(id_ticket)
            tv = self.cb_tipo_vis.get()
            id_precio = self._resolver_precio_entrada(id_parque, self.tipos_visitante[tv])
            if id_precio is None:
                messagebox.showerror('Sin precio',
                                     'No hay precio vigente para ese parque y tipo de visitante.')
                return
        elif tipo == 'Tour':
            id_tour = self.tours.get(self.cb_item.get())
        else:
            id_atraccion = self.atracciones.get(self.cb_item.get())

        ok, msg = self.ejecutar_sp(
            '{CALL ventas.LineaVenta_Actualizar (?, ?, ?, ?, ?)}',
            (id_linea, cant, id_precio, id_tour, id_atraccion)
        )
        if ok:
            self._refrescar_lineas()
            self._refrescar_tickets()
        else:
            messagebox.showerror('Error', msg)

    def _eliminar_linea(self):
        sel = self.tree_ln.selection()
        if not sel:
            messagebox.showwarning('Validacion', 'Seleccione una linea de la grilla.')
            return
        id_linea = self.tree_ln.item(sel[0])['values'][0]
        if not messagebox.askyesno('Confirmar', f'Eliminar la linea {id_linea}?'):
            return
        ok, msg = self.ejecutar_sp(
            '{CALL ventas.LineaVenta_Eliminar (?)}', (id_linea,))
        if ok:
            self._refrescar_lineas()
            self._refrescar_tickets()
        else:
            messagebox.showerror('Error', msg)

    def _refrescar_lineas(self):
        for i in self.tree_ln.get_children():
            self.tree_ln.delete(i)
        id_ticket = self._id_ticket_seleccionado()
        if not id_ticket:
            return
        cols, filas = self.consultar('''
            SELECT idLineaVenta, descripcion, cantidad, precioUnitario, subtotal
            FROM ventas.LineaVenta
            WHERE ticketAsociado = ?
            ORDER BY idLineaVenta
        ''', (id_ticket,))
        for f in filas:
            self.tree_ln.insert('', 'end', values=(
                f.idLineaVenta, f.descripcion, f.cantidad,
                f'{f.precioUnitario:.2f}', f'{f.subtotal:.2f}'
            ))

    def _on_select_linea(self, _evt):
        sel = self.tree_ln.selection()
        if not sel:
            return
        vals = self.tree_ln.item(sel[0])['values']
        # Cargar cantidad en el formulario para facilitar la edicion
        self.e_cantidad.delete(0, 'end')
        self.e_cantidad.insert(0, str(vals[2]))


if __name__ == '__main__':
    app = AppVentas()
    app.mainloop()
