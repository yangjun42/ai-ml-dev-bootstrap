def test_import_numpy() -> None:
    import numpy as np

    assert np.arange(3).sum() == 3
