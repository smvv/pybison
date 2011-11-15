extern DL_IMPORT(PyObject) *(py_callback(PyObject *,char (*),int ,int ,void (*),...));
extern DL_IMPORT(void) (py_input(PyObject *,char (*),int (*),int ));
extern DL_IMPORT(void) initbison_(void);
